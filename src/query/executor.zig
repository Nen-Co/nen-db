// NenDB Cypher Query Execution Engine
// Executes parsed Cypher queries against the GraphDB

const std = @import("std");
const cypher = @import("cypher/ast.zig");
const nendb = @import("../lib.zig");
const algorithms = @import("../algorithms/algorithms.zig");

pub const QueryExecutor = struct {
    db: *nendb.GraphDB,
    allocator: std.mem.Allocator,
    variables: std.StringHashMap(QueryValue),
    current_row: QueryRow,
    // Track matched nodes and relationships for variable lookup
    matched_nodes: std.StringHashMap(*nendb.Node),
    matched_relationships: std.StringHashMap(*nendb.Edge),

    pub fn init(db: *nendb.GraphDB, allocator: std.mem.Allocator) QueryExecutor {
        return QueryExecutor{
            .db = db,
            .allocator = allocator,
            .variables = std.StringHashMap(QueryValue).init(allocator),
            .current_row = QueryRow.init(allocator),
            .matched_nodes = std.StringHashMap(*nendb.Node).init(allocator),
            .matched_relationships = std.StringHashMap(*nendb.Edge).init(allocator),
        };
    }

    pub fn deinit(self: *QueryExecutor) void {
        self.variables.deinit();
        self.current_row.deinit();
        self.matched_nodes.deinit();
        self.matched_relationships.deinit();
    }

    pub fn execute(self: *QueryExecutor, statement: cypher.Statement) !QueryResult {
        return switch (statement) {
            .query => |query| try self.execute_query(query),
        };
    }

    fn execute_query(self: *QueryExecutor, query: cypher.Query) !QueryResult {
        var result = QueryResult.init(self.allocator);
        errdefer result.deinit();

        for (query.parts) |part| {
            for (part.clauses) |clause| {
                try self.execute_clause(clause, &result);
            }
        }

        return result;
    }

    fn execute_clause(self: *QueryExecutor, clause: cypher.Clause, result: *QueryResult) !void {
        switch (clause) {
            .Match => |match_clause| try self.execute_match(match_clause, result),
            .OptionalMatch => |match_clause| try self.execute_optional_match(match_clause, result),
            .With => |with_clause| try self.execute_with(with_clause, result),
            .Create => |create_clause| try self.execute_create(create_clause, result),
            .Merge => |merge_clause| try self.execute_merge(merge_clause, result),
            .Set => |set_clause| try self.execute_set(set_clause, result),
            .Delete => |delete_clause| try self.execute_delete(delete_clause, result),
            .DetachDelete => |delete_clause| try self.execute_detach_delete(delete_clause, result),
            .Unwind => |unwind_clause| try self.execute_unwind(unwind_clause, result),
            .Remove => |remove_clause| try self.execute_remove(remove_clause, result),
            .OrderBy => |order_by_clause| try self.execute_order_by(order_by_clause, result),
            .Skip => |skip_clause| try self.execute_skip(skip_clause, result),
            .Limit => |limit_clause| try self.execute_limit(limit_clause, result),
            .Using => |using_clause| try self.execute_using(using_clause, result),
            .Return => |return_clause| try self.execute_return(return_clause, result),
        }
    }

    fn execute_match(self: *QueryExecutor, match_clause: cypher.Match, result: *QueryResult) !void {
        std.debug.print("Executing MATCH clause\n", .{});

        var row = QueryRow.init(self.allocator);
        defer row.deinit();

        // Simple pattern matching - for now, just handle basic node patterns
        for (match_clause.pattern.paths) |path| {
            for (path.elements) |element| {
                switch (element) {
                    .node => |node_pattern| try self.match_node_pattern(node_pattern, &row),
                    .relationship => |rel_pattern| try self.match_relationship_pattern(rel_pattern, &row),
                }
            }
        }

        if (match_clause.where) |where_expr| {
            if (!try self.evaluate_where(where_expr, &row)) {
                return; // Skip this row if WHERE condition fails
            }
        }

        try result.add_row(row);
    }

    fn execute_create(self: *QueryExecutor, create_clause: cypher.Create, result: *QueryResult) !void {
        std.debug.print("Executing CREATE clause\n", .{});

        for (create_clause.pattern.paths) |path| {
            for (path.elements) |element| {
                switch (element) {
                    .node => |node_pattern| try self.create_node_pattern(node_pattern, result),
                    .relationship => |rel_pattern| try self.create_relationship_pattern(rel_pattern, result),
                }
            }
        }
    }

    fn execute_return(self: *QueryExecutor, return_clause: cypher.Return, result: *QueryResult) !void {
        _ = return_clause;
        std.debug.print("Executing RETURN clause\n", .{});

        // For now, just return the current result
        // In a full implementation, this would format the output according to the return items
        _ = self;
        _ = result;
    }

    fn execute_using(self: *QueryExecutor, using_clause: cypher.Using, result: *QueryResult) !void {
        std.debug.print("Executing USING clause with algorithm: {s}\n", .{using_clause.algorithm});

        // Parse algorithm type from string
        const algorithm_type = parseAlgorithmType(using_clause.algorithm) orelse {
            std.debug.print("Unknown algorithm: {s}\n", .{using_clause.algorithm});
            return;
        };

        // Execute the algorithm based on type
        const algorithm_result = try algorithms.AlgorithmExecutor.executeDefault(
            algorithm_type,
            &self.db.node_pool,
            &self.db.edge_pool,
            null, // source_node_id - could be extracted from MATCH clause
            self.allocator,
        );
        defer algorithms.AlgorithmExecutor.deinitResult(algorithm_result);

        // Store algorithm result in variables for RETURN clause
        try self.store_algorithm_result(algorithm_result, result);
    }

    fn execute_optional_match(self: *QueryExecutor, match_clause: cypher.Match, result: *QueryResult) !void {
        std.debug.print("Executing OPTIONAL MATCH clause\n", .{});
        
        // OPTIONAL MATCH behaves like MATCH but doesn't fail if no matches are found
        // Instead, it returns null values for unmatched patterns
        var row = QueryRow.init(self.allocator);
        defer row.deinit();

        // Try to match the pattern
        var matched = false;
        for (match_clause.pattern.paths) |path| {
            for (path.elements) |element| {
                switch (element) {
                    .node => |node_pattern| {
                        if (try self.match_node_pattern_optional(node_pattern, &row)) {
                            matched = true;
                        }
                    },
                    .relationship => |rel_pattern| {
                        if (try self.match_relationship_pattern_optional(rel_pattern, &row)) {
                            matched = true;
                        }
                    },
                }
            }
        }

        // Apply WHERE clause if present
        if (match_clause.where) |where_expr| {
            if (!try self.evaluate_where(where_expr, &row)) {
                matched = false;
            }
        }

        // Always add the row, even if no matches (with null values)
        if (!matched) {
            // Set null values for unmatched variables
            for (match_clause.pattern.paths) |path| {
                for (path.elements) |element| {
                    switch (element) {
                        .node => |node_pattern| {
                            if (node_pattern.variable) |var_name| {
                                try row.set_variable(var_name, .null);
                            }
                        },
                        .relationship => |rel_pattern| {
                            if (rel_pattern.variable) |var_name| {
                                try row.set_variable(var_name, .null);
                            }
                        },
                    }
                }
            }
        }

        try result.add_row(row);
    }

    fn execute_with(self: *QueryExecutor, with_clause: cypher.With, result: *QueryResult) !void {
        std.debug.print("Executing WITH clause\n", .{});
        
        // WITH clause processes intermediate results and can filter/transform them
        // For now, we'll implement basic WITH functionality
        
        // Process the return items to create new variables
        for (with_clause.items) |item| {
            const value = try self.evaluate_expression(item.expr);
            if (item.alias) |alias| {
                // Store the result with the alias
                try self.variables.put(alias, value);
            }
        }

        // Apply WHERE clause if present
        if (with_clause.where) |where_expr| {
            if (!try self.evaluate_where(where_expr, null)) {
                // Skip this result if WHERE condition fails
                return;
            }
        }

        // Apply ORDER BY if present
        if (with_clause.order_by) |order_by| {
            try self.execute_order_by(order_by, result);
        }

        // Apply SKIP/LIMIT if present
        if (with_clause.skip_limit) |skip_limit| {
            if (skip_limit.skip) |skip_count| {
                try self.execute_skip(.{ .count = skip_count }, result);
            }
            if (skip_limit.limit) |limit_count| {
                try self.execute_limit(.{ .count = limit_count }, result);
            }
        }
    }

    fn execute_merge(self: *QueryExecutor, merge_clause: cypher.Merge, result: *QueryResult) !void {
        std.debug.print("Executing MERGE clause\n", .{});
        
        // MERGE is an upsert operation: create if doesn't exist, otherwise match
        for (merge_clause.pattern.paths) |path| {
            for (path.elements) |element| {
                switch (element) {
                    .node => |node_pattern| try self.merge_node_pattern(node_pattern, result),
                    .relationship => |rel_pattern| try self.merge_relationship_pattern(rel_pattern, result),
                }
            }
        }
    }

    fn execute_set(self: *QueryExecutor, set_clause: cypher.Set, result: *QueryResult) !void {
        _ = result;
        std.debug.print("Executing SET clause\n", .{});
        
        for (set_clause.items) |item| {
            switch (item) {
                .property => |prop| {
                    const value = try self.evaluate_expression(prop.value);
                    try self.set_property(prop.target, value);
                },
                .map_merge => |merge| {
                    const map_value = try self.evaluate_expression(.{ .map = merge.map });
                    try self.merge_properties(merge.variable, map_value);
                },
            }
        }
    }

    fn execute_delete(self: *QueryExecutor, delete_clause: cypher.Delete, result: *QueryResult) !void {
        _ = result;
        std.debug.print("Executing DELETE clause\n", .{});
        
        for (delete_clause.expressions) |expr| {
            const value = try self.evaluate_expression(expr);
            try self.delete_entity(value);
        }
    }

    fn execute_detach_delete(self: *QueryExecutor, delete_clause: cypher.Delete, result: *QueryResult) !void {
        _ = result;
        std.debug.print("Executing DETACH DELETE clause\n", .{});
        
        // DETACH DELETE removes the entity and all its relationships
        for (delete_clause.expressions) |expr| {
            const value = try self.evaluate_expression(expr);
            try self.detach_delete_entity(value);
        }
    }

    fn execute_unwind(self: *QueryExecutor, unwind_clause: cypher.Unwind, result: *QueryResult) !void {
        std.debug.print("Executing UNWIND clause\n", .{});
        
        // UNWIND expands a list into individual rows
        const list_value = try self.evaluate_expression(unwind_clause.expr);
        
        switch (list_value) {
            .list => |list| {
                for (list.items) |item| {
                    var new_row = QueryRow.init(self.allocator);
                    defer new_row.deinit();
                    
                    // Copy current variables
                    try new_row.copy_from(&self.current_row);
                    
                    // Set the unwound value
                    try new_row.set_variable(unwind_clause.alias, item);
                    
                    try result.add_row(new_row);
                }
            },
            else => {
                // If not a list, treat as single item
                var new_row = QueryRow.init(self.allocator);
                defer new_row.deinit();
                
                try new_row.copy_from(&self.current_row);
                try new_row.set_variable(unwind_clause.alias, list_value);
                
                try result.add_row(new_row);
            },
        }
    }

    fn execute_remove(self: *QueryExecutor, remove_clause: cypher.Remove, result: *QueryResult) !void {
        _ = result;
        std.debug.print("Executing REMOVE clause\n", .{});
        
        for (remove_clause.items) |item| {
            try self.remove_property(item);
        }
    }

    fn execute_order_by(self: *QueryExecutor, order_by_clause: cypher.OrderBy, result: *QueryResult) !void {
        _ = self;
        _ = result;
        std.debug.print("Executing ORDER BY clause\n", .{});
        
        // Sort the result rows based on the order by criteria
        std.sort.insertion(cypher.SortItem, order_by_clause.items, {}, struct {
            fn lessThan(_: void, a: cypher.SortItem, b: cypher.SortItem) bool {
                // For now, just sort by expression value
                // In a full implementation, this would compare actual values
                return a.descending != b.descending;
            }
        }.lessThan);
    }

    fn execute_skip(self: *QueryExecutor, skip_clause: cypher.Skip, result: *QueryResult) !void {
        _ = self;
        std.debug.print("Executing SKIP clause\n", .{});
        
        // Skip the first N rows from the result
        if (result.rows.items.len > skip_clause.count) {
            const skip_start = skip_clause.count;
            const skip_end = result.rows.items.len;
            
            // Remove the skipped rows
            for (skip_start..skip_end) |i| {
                result.rows.items[i - skip_start] = result.rows.items[i];
            }
            result.rows.shrinkRetainingCapacity(skip_start);
        } else {
            // Skip more rows than we have, so clear all
            result.rows.clearRetainingCapacity();
        }
    }

    fn execute_limit(self: *QueryExecutor, limit_clause: cypher.Limit, result: *QueryResult) !void {
        _ = self;
        std.debug.print("Executing LIMIT clause\n", .{});
        
        // Limit the result to N rows
        if (result.rows.items.len > limit_clause.count) {
            result.rows.shrinkRetainingCapacity(limit_clause.count);
        }
    }

    fn parseAlgorithmType(algorithm_name: []const u8) ?algorithms.AlgorithmType {
        if (std.mem.eql(u8, algorithm_name, "BFS")) {
            return .bfs;
        } else if (std.mem.eql(u8, algorithm_name, "DIJKSTRA")) {
            return .dijkstra;
        } else if (std.mem.eql(u8, algorithm_name, "PAGERANK")) {
            return .pagerank;
        }
        return null;
    }

    fn store_algorithm_result(self: *QueryExecutor, algorithm_result: algorithms.AlgorithmResult, result: *QueryResult) !void {
        switch (algorithm_result) {
            .bfs => |bfs_result| {
                // Store BFS results in variables
                const visited_var = QueryValue{ .list = bfs_result.visited_nodes };
                const distances_var = QueryValue{ .list = bfs_result.distances };

                var row = QueryRow.init(self.allocator);
                defer row.deinit();
                try row.set_variable("visited_nodes", visited_var);
                try row.set_variable("distances", distances_var);
                try result.add_row(row);
            },
            .dijkstra => |dijkstra_result| {
                // Store Dijkstra results in variables
                const distances_var = QueryValue{ .list = dijkstra_result.distances };
                const predecessors_var = QueryValue{ .list = dijkstra_result.predecessors };

                var row = QueryRow.init(self.allocator);
                defer row.deinit();
                try row.set_variable("distances", distances_var);
                try row.set_variable("predecessors", predecessors_var);
                try result.add_row(row);
            },
            .pagerank => |pagerank_result| {
                // Store PageRank results in variables
                const scores_var = QueryValue{ .list = pagerank_result.scores };
                const iterations_var = QueryValue{ .integer = pagerank_result.iterations };
                const converged_var = QueryValue{ .boolean = pagerank_result.converged };

                var row = QueryRow.init(self.allocator);
                defer row.deinit();
                try row.set_variable("scores", scores_var);
                try row.set_variable("iterations", iterations_var);
                try row.set_variable("converged", converged_var);
                try result.add_row(row);
            },
        }
    }

    fn match_node_pattern(self: *QueryExecutor, node_pattern: cypher.NodePattern, row: *QueryRow) !void {
        std.debug.print("Matching node pattern: var={?s}, labels={any}\n", .{ node_pattern.variable, node_pattern.labels });

        // Try to find a node in the database
        // For now, we'll create a simple node or find an existing one
        var node: nendb.Node = undefined;
        
        if (node_pattern.variable) |var_name| {
            // Check if we already have this variable
            if (self.matched_nodes.get(var_name)) |existing_node_ptr| {
                node = existing_node_ptr.*;
            } else {
                // Create a new node or find one in the database
                // For now, create a simple node with ID based on variable name
                const node_id = std.hash.Wyhash.hash(0, var_name);
                node = nendb.Node{
                    .id = node_id,
                    .kind = if (node_pattern.labels.len > 0) 1 else 0,
                    .props = [_]u8{0} ** 128,
                };
                
                // Try to insert the node (it might already exist)
                self.db.insert_node(node) catch |err| {
                    if (err != error.NodeAlreadyExists) return err;
                    // Node already exists, try to look it up
                    if (self.db.lookup_node(node_id)) |existing_node| {
                        node = existing_node;
                    }
                };
                
                // Store the node for future reference
                const node_ptr = try self.allocator.create(nendb.Node);
                node_ptr.* = node;
                try self.matched_nodes.put(var_name, node_ptr);
            }
            
            const node_value = QueryValue{ .node = node };
            try row.set_variable(var_name, node_value);
        }
    }

    fn match_relationship_pattern(self: *QueryExecutor, rel_pattern: cypher.RelationshipPattern, row: *QueryRow) !void {
        std.debug.print("Matching relationship pattern: var={?s}, types={any}\n", .{ rel_pattern.variable, rel_pattern.types });

        // Try to find a relationship in the database
        // For now, we'll create a simple edge or find an existing one
        var edge: nendb.Edge = undefined;
        
        if (rel_pattern.variable) |var_name| {
            // Check if we already have this variable
            if (self.matched_relationships.get(var_name)) |existing_edge_ptr| {
                edge = existing_edge_ptr.*;
            } else {
                // Create a new edge or find one in the database
                // For now, create a simple edge with IDs based on variable name
                const edge_id = std.hash.Wyhash.hash(0, var_name);
                edge = nendb.Edge{
                    .from = edge_id,
                    .to = edge_id + 1,
                    .label = if (rel_pattern.types.len > 0) 1 else 0,
                    .props = [_]u8{0} ** nendb.constants.data.edge_props_size,
                };
                
                // Try to insert the edge (it might already exist)
                self.db.insert_edge(edge) catch |err| {
                    if (err != error.EdgeAlreadyExists) return err;
                    // Edge already exists, try to look it up
                    if (self.db.lookup_edge(edge.from, edge.to)) |existing_edge| {
                        edge = existing_edge;
                    }
                };
                
                // Store the edge for future reference
                const edge_ptr = try self.allocator.create(nendb.Edge);
                edge_ptr.* = edge;
                try self.matched_relationships.put(var_name, edge_ptr);
            }
            
            const edge_value = QueryValue{ .edge = edge };
            try row.set_variable(var_name, edge_value);
        }
    }

    fn create_node_pattern(self: *QueryExecutor, node_pattern: cypher.NodePattern, result: *QueryResult) !void {
        std.debug.print("Creating node: var={?s}, labels={any}\n", .{ node_pattern.variable, node_pattern.labels });

        const var_name = node_pattern.variable orelse "node";

        // Generate a new node ID
        const node_id = std.hash.Wyhash.hash(0, var_name);

        const node = nendb.Node{
            .id = node_id,
            .kind = if (node_pattern.labels.len > 0) 1 else 0,
            .props = [_]u8{0} ** 128, // For now, empty properties
        };

        try self.db.insert_node(node);

        const node_value = QueryValue{ .node = node };
        var row = QueryRow.init(self.allocator);
        defer row.deinit();
        try row.set_variable(var_name, node_value);
        try result.add_row(row);
    }

    fn create_relationship_pattern(self: *QueryExecutor, rel_pattern: cypher.RelationshipPattern, result: *QueryResult) !void {
        _ = result;
        std.debug.print("Creating relationship: var={?s}, types={any}\n", .{ rel_pattern.variable, rel_pattern.types });

        // For now, create a simple edge
        const edge = nendb.Edge{
            .from = 1, // Would get from context
            .to = 2, // Would get from context
            .label = 1,
            .props = [_]u8{0} ** nendb.constants.data.edge_props_size,
        };

        try self.db.insert_edge(edge);
    }

    fn match_node_pattern_optional(self: *QueryExecutor, node_pattern: cypher.NodePattern, row: *QueryRow) !bool {
        _ = self;
        _ = node_pattern;
        _ = row;
        // TODO: Implement optional node pattern matching
        return false;
    }

    fn match_relationship_pattern_optional(self: *QueryExecutor, rel_pattern: cypher.RelationshipPattern, row: *QueryRow) !bool {
        _ = self;
        _ = rel_pattern;
        _ = row;
        // TODO: Implement optional relationship pattern matching
        return false;
    }

    fn merge_node_pattern(self: *QueryExecutor, node_pattern: cypher.NodePattern, result: *QueryResult) !void {
        _ = self;
        _ = node_pattern;
        _ = result;
        // TODO: Implement node merging (create if not exists)
    }

    fn merge_relationship_pattern(self: *QueryExecutor, rel_pattern: cypher.RelationshipPattern, result: *QueryResult) !void {
        _ = self;
        _ = rel_pattern;
        _ = result;
        // TODO: Implement relationship merging
    }

    fn set_property(self: *QueryExecutor, target: cypher.PropertySelector, value: QueryValue) !void {
        _ = self;
        _ = target;
        _ = value;
        // TODO: Implement property setting
    }

    fn merge_properties(self: *QueryExecutor, variable: []const u8, map_value: QueryValue) !void {
        _ = self;
        _ = variable;
        _ = map_value;
        // TODO: Implement property merging
    }

    fn delete_entity(self: *QueryExecutor, value: QueryValue) !void {
        _ = self;
        _ = value;
        // TODO: Implement entity deletion
    }

    fn detach_delete_entity(self: *QueryExecutor, value: QueryValue) !void {
        _ = self;
        _ = value;
        // TODO: Implement detach delete (delete entity and all relationships)
    }

    fn remove_property(self: *QueryExecutor, property_selector: cypher.PropertySelector) !void {
        _ = self;
        _ = property_selector;
        // TODO: Implement property removal
    }

    fn evaluate_expression(self: *QueryExecutor, expr: cypher.Expression) !QueryValue {
        return switch (expr) {
            // Primary types
            .variable => |var_name| {
                return try self.lookup_variable(var_name);
            },
            .property => |prop| {
                return try self.lookup_property(prop);
            },
            .string => |s| .{ .string = s },
            .integer => |i| .{ .integer = i },
            .float => |f| .{ .float = f },
            .boolean => |b| .{ .boolean = b },
            .null => .null,
            .map => |m| {
                // TODO: Convert map to QueryValue
                _ = m;
                return .null;
            },
            .list => |l| {
                // TODO: Convert list to QueryValue
                _ = l;
                return .null;
            },
            
            // Comparison Operators
            .eq => |cmp| {
                const left = try self.evaluate_expression(cmp.left.*);
                const right = try self.evaluate_expression(cmp.right.*);
                return .{ .boolean = try self.compare_values(left, right) == 0 };
            },
            .ne => |cmp| {
                const left = try self.evaluate_expression(cmp.left.*);
                const right = try self.evaluate_expression(cmp.right.*);
                return .{ .boolean = try self.compare_values(left, right) != 0 };
            },
            .lt => |cmp| {
                const left = try self.evaluate_expression(cmp.left.*);
                const right = try self.evaluate_expression(cmp.right.*);
                return .{ .boolean = try self.compare_values(left, right) < 0 };
            },
            .lte => |cmp| {
                const left = try self.evaluate_expression(cmp.left.*);
                const right = try self.evaluate_expression(cmp.right.*);
                return .{ .boolean = try self.compare_values(left, right) <= 0 };
            },
            .gt => |cmp| {
                const left = try self.evaluate_expression(cmp.left.*);
                const right = try self.evaluate_expression(cmp.right.*);
                return .{ .boolean = try self.compare_values(left, right) > 0 };
            },
            .gte => |cmp| {
                const left = try self.evaluate_expression(cmp.left.*);
                const right = try self.evaluate_expression(cmp.right.*);
                return .{ .boolean = try self.compare_values(left, right) >= 0 };
            },
            
            // Arithmetic Operators
            .add => |arith| {
                const left = try self.evaluate_expression(arith.left.*);
                const right = try self.evaluate_expression(arith.right.*);
                return try self.arithmetic_operation(left, right, .add);
            },
            .sub => |arith| {
                const left = try self.evaluate_expression(arith.left.*);
                const right = try self.evaluate_expression(arith.right.*);
                return try self.arithmetic_operation(left, right, .sub);
            },
            .mul => |arith| {
                const left = try self.evaluate_expression(arith.left.*);
                const right = try self.evaluate_expression(arith.right.*);
                return try self.arithmetic_operation(left, right, .mul);
            },
            .div => |arith| {
                const left = try self.evaluate_expression(arith.left.*);
                const right = try self.evaluate_expression(arith.right.*);
                return try self.arithmetic_operation(left, right, .div);
            },
            .mod => |arith| {
                const left = try self.evaluate_expression(arith.left.*);
                const right = try self.evaluate_expression(arith.right.*);
                return try self.arithmetic_operation(left, right, .mod);
            },
            
            // Logical Operators
            .logical_and => |logical| {
                const left = try self.evaluate_expression(logical.left.*);
                const right = try self.evaluate_expression(logical.right.*);
                return .{ .boolean = left.boolean and right.boolean };
            },
            .logical_or => |logical| {
                const left = try self.evaluate_expression(logical.left.*);
                const right = try self.evaluate_expression(logical.right.*);
                return .{ .boolean = left.boolean or right.boolean };
            },
            .logical_not => |not_expr| {
                const expr_val = try self.evaluate_expression(not_expr.expr.*);
                return .{ .boolean = !expr_val.boolean };
            },
            
            // String Functions
            .toUpper => |func| {
                const expr_val = try self.evaluate_expression(func.expr.*);
                if (expr_val != .string) return error.TypeError;
                // TODO: Implement toUpper
                return expr_val;
            },
            .toLower => |func| {
                const expr_val = try self.evaluate_expression(func.expr.*);
                if (expr_val != .string) return error.TypeError;
                // TODO: Implement toLower
                return expr_val;
            },
            .trim => |func| {
                const expr_val = try self.evaluate_expression(func.expr.*);
                if (expr_val != .string) return error.TypeError;
                // TODO: Implement trim
                return expr_val;
            },
            .substring => |func| {
                const expr_val = try self.evaluate_expression(func.expr.*);
                const start_val = try self.evaluate_expression(func.start.*);
                const length_val = try self.evaluate_expression(func.length.*);
                if (expr_val != .string or start_val != .integer or length_val != .integer) return error.TypeError;
                // TODO: Implement substring
                return expr_val;
            },
            
            // Mathematical Functions
            .abs => |func| {
                const expr_val = try self.evaluate_expression(func.expr.*);
                return try self.math_function(expr_val, .abs);
            },
            .round => |func| {
                const expr_val = try self.evaluate_expression(func.expr.*);
                return try self.math_function(expr_val, .round);
            },
            .ceil => |func| {
                const expr_val = try self.evaluate_expression(func.expr.*);
                return try self.math_function(expr_val, .ceil);
            },
            .floor => |func| {
                const expr_val = try self.evaluate_expression(func.expr.*);
                return try self.math_function(expr_val, .floor);
            },
            .sqrt => |func| {
                const expr_val = try self.evaluate_expression(func.expr.*);
                return try self.math_function(expr_val, .sqrt);
            },
            
            // Aggregation Functions
            .count => |agg| {
                const expr_val = try self.evaluate_expression(agg.expr.*);
                // TODO: Implement count aggregation
                _ = agg.distinct;
                _ = expr_val;
                return .{ .integer = 0 };
            },
            .sum => |agg| {
                const expr_val = try self.evaluate_expression(agg.expr.*);
                // TODO: Implement sum aggregation
                _ = expr_val;
                return .{ .integer = 0 };
            },
            .avg => |agg| {
                const expr_val = try self.evaluate_expression(agg.expr.*);
                // TODO: Implement avg aggregation
                _ = expr_val;
                return .{ .float = 0.0 };
            },
            .min => |agg| {
                const expr_val = try self.evaluate_expression(agg.expr.*);
                // TODO: Implement min aggregation
                _ = agg.distinct;
                return expr_val;
            },
            .max => |agg| {
                const expr_val = try self.evaluate_expression(agg.expr.*);
                // TODO: Implement max aggregation
                _ = agg.distinct;
                return expr_val;
            },
        };
    }

    fn evaluate_where(self: *QueryExecutor, where_expr: cypher.Expression, row: ?*QueryRow) !bool {
        _ = row; // TODO: Use row for variable lookup
        const result = try self.evaluate_expression(where_expr);
        return result.boolean;
    }

    fn lookup_variable(self: *QueryExecutor, var_name: []const u8) !QueryValue {
        // First check if it's a matched node
        if (self.matched_nodes.get(var_name)) |node_ptr| {
            return .{ .node = node_ptr.* };
        }
        
        // Then check if it's a matched relationship
        if (self.matched_relationships.get(var_name)) |edge_ptr| {
            return .{ .edge = edge_ptr.* };
        }
        
        // Finally check variables map
        if (self.variables.get(var_name)) |value| {
            return value;
        }
        
        // Return null if not found
        return .null;
    }

    fn lookup_property(self: *QueryExecutor, prop: cypher.PropertySelector) !QueryValue {
        // Get the base variable
        const base_value = try self.lookup_variable(prop.variable);
        
        switch (base_value) {
            .node => |node| {
                // Look up property in node
                if (prop.keys.len > 0) {
                    const key = prop.keys[0];
                    return try self.get_node_property(node, key);
                }
            },
            .edge => |edge| {
                // Look up property in edge
                if (prop.keys.len > 0) {
                    const key = prop.keys[0];
                    return try self.get_edge_property(edge, key);
                }
            },
            else => {},
        }
        
        return .null;
    }

    fn get_node_property(_: *QueryExecutor, node: nendb.Node, key: []const u8) !QueryValue {
        // For now, return a placeholder based on common node properties
        if (std.mem.eql(u8, key, "id")) {
            return .{ .integer = node.id };
        } else if (std.mem.eql(u8, key, "kind")) {
            return .{ .integer = node.kind };
        } else if (std.mem.eql(u8, key, "name")) {
            // TODO: Implement actual property lookup from node data
            return .{ .string = "Node" };
        } else if (std.mem.eql(u8, key, "age")) {
            // TODO: Implement actual property lookup
            return .{ .integer = 25 };
        } else if (std.mem.eql(u8, key, "salary")) {
            // TODO: Implement actual property lookup
            return .{ .integer = 50000 };
        }
        
        return .null;
    }

    fn get_edge_property(_: *QueryExecutor, edge: nendb.Edge, key: []const u8) !QueryValue {
        // For now, return a placeholder based on common edge properties
        if (std.mem.eql(u8, key, "from")) {
            return .{ .integer = edge.from };
        } else if (std.mem.eql(u8, key, "to")) {
            return .{ .integer = edge.to };
        } else if (std.mem.eql(u8, key, "kind")) {
            return .{ .integer = edge.kind };
        } else if (std.mem.eql(u8, key, "weight")) {
            // TODO: Implement actual property lookup
            return .{ .float = 1.0 };
        }
        
        return .null;
    }

    fn compare_values(_: *QueryExecutor, left: QueryValue, right: QueryValue) !i32 {
        return switch (left) {
            .integer => |l| switch (right) {
                .integer => |r| if (l < r) -1 else if (l > r) 1 else 0,
                .float => |r| if (@as(f64, @floatFromInt(l)) < r) -1 else if (@as(f64, @floatFromInt(l)) > r) 1 else 0,
                else => return error.TypeError,
            },
            .float => |l| switch (right) {
                .integer => |r| if (l < @as(f64, @floatFromInt(r))) -1 else if (l > @as(f64, @floatFromInt(r))) 1 else 0,
                .float => |r| if (l < r) -1 else if (l > r) 1 else 0,
                else => return error.TypeError,
            },
            .string => |l| switch (right) {
                .string => |r| if (std.mem.lessThan(u8, l, r)) -1 else if (std.mem.greaterThan(u8, l, r)) 1 else 0,
                else => return error.TypeError,
            },
            .boolean => |l| switch (right) {
                .boolean => |r| if (l == r) 0 else if (!l and r) -1 else 1,
                else => return error.TypeError,
            },
            .null => switch (right) {
                .null => 0,
                else => -1, // null is less than everything
            },
            else => return error.TypeError,
        };
    }

    fn arithmetic_operation(self: *QueryExecutor, left: QueryValue, right: QueryValue, op: enum { add, sub, mul, div, mod }) !QueryValue {
        return switch (op) {
            .add => switch (left) {
                .integer => |l| switch (right) {
                    .integer => |r| .{ .integer = l + r },
                    .float => |r| .{ .float = @as(f64, @floatFromInt(l)) + r },
                    else => return error.TypeError,
                },
                .float => |l| switch (right) {
                    .integer => |r| .{ .float = l + @as(f64, @floatFromInt(r)) },
                    .float => |r| .{ .float = l + r },
                    else => return error.TypeError,
                },
                .string => |l| switch (right) {
                    .string => |r| .{ .string = try std.fmt.allocPrint(self.allocator, "{s}{s}", .{ l, r }) },
                    else => return error.TypeError,
                },
                else => return error.TypeError,
            },
            .sub => switch (left) {
                .integer => |l| switch (right) {
                    .integer => |r| .{ .integer = l - r },
                    .float => |r| .{ .float = @as(f64, @floatFromInt(l)) - r },
                    else => return error.TypeError,
                },
                .float => |l| switch (right) {
                    .integer => |r| .{ .float = l - @as(f64, @floatFromInt(r)) },
                    .float => |r| .{ .float = l - r },
                    else => return error.TypeError,
                },
                else => return error.TypeError,
            },
            .mul => switch (left) {
                .integer => |l| switch (right) {
                    .integer => |r| .{ .integer = l * r },
                    .float => |r| .{ .float = @as(f64, @floatFromInt(l)) * r },
                    else => return error.TypeError,
                },
                .float => |l| switch (right) {
                    .integer => |r| .{ .float = l * @as(f64, @floatFromInt(r)) },
                    .float => |r| .{ .float = l * r },
                    else => return error.TypeError,
                },
                else => return error.TypeError,
            },
            .div => switch (left) {
                .integer => |l| switch (right) {
                    .integer => |r| if (r == 0) return error.DivisionByZero else .{ .integer = l / r },
                    .float => |r| if (r == 0.0) return error.DivisionByZero else .{ .float = @as(f64, @floatFromInt(l)) / r },
                    else => return error.TypeError,
                },
                .float => |l| switch (right) {
                    .integer => |r| if (r == 0) return error.DivisionByZero else .{ .float = l / @as(f64, @floatFromInt(r)) },
                    .float => |r| if (r == 0.0) return error.DivisionByZero else .{ .float = l / r },
                    else => return error.TypeError,
                },
                else => return error.TypeError,
            },
            .mod => switch (left) {
                .integer => |l| switch (right) {
                    .integer => |r| if (r == 0) return error.DivisionByZero else .{ .integer = l % r },
                    else => return error.TypeError,
                },
                else => return error.TypeError,
            },
        };
    }

    fn math_function(self: *QueryExecutor, value: QueryValue, func: enum { abs, round, ceil, floor, sqrt }) !QueryValue {
        _ = self;
        return switch (func) {
            .abs => switch (value) {
                .integer => |i| .{ .integer = if (i < 0) -i else i },
                .float => |f| .{ .float = if (f < 0) -f else f },
                else => return error.TypeError,
            },
            .round => switch (value) {
                .integer => |i| .{ .integer = i },
                .float => |f| .{ .integer = @intFromFloat(@round(f)) },
                else => return error.TypeError,
            },
            .ceil => switch (value) {
                .integer => |i| .{ .integer = i },
                .float => |f| .{ .integer = @intFromFloat(@ceil(f)) },
                else => return error.TypeError,
            },
            .floor => switch (value) {
                .integer => |i| .{ .integer = i },
                .float => |f| .{ .integer = @intFromFloat(@floor(f)) },
                else => return error.TypeError,
            },
            .sqrt => switch (value) {
                .integer => |i| if (i < 0) return error.DomainError else .{ .float = @sqrt(@as(f64, @floatFromInt(i))) },
                .float => |f| if (f < 0) return error.DomainError else .{ .float = @sqrt(f) },
                else => return error.TypeError,
            },
        };
    }
};

pub const QueryResult = struct {
    rows: std.ArrayList(QueryRow),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) QueryResult {
        return QueryResult{
            .rows = std.ArrayList(QueryRow).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *QueryResult) void {
        for (self.rows.items) |*row| {
            row.deinit();
        }
        self.rows.deinit();
    }

    pub fn add_row(self: *QueryResult, row: QueryRow) !void {
        var new_row = QueryRow.init(self.allocator);
        try new_row.copy_from(&row);
        try self.rows.append(new_row);
    }

    pub fn count(self: *const QueryResult) usize {
        return self.rows.items.len;
    }

    pub fn format(self: *const QueryResult, writer: anytype) !void {
        try writer.writeAll("Query Result:\n");
        try writer.print("Total rows: {}\n", .{self.count()});

        for (self.rows.items, 0..) |row, i| {
            try writer.print("Row {}:\n", .{i});
            try row.format(writer);
        }
    }
};

pub const QueryRow = struct {
    variables: std.StringHashMap(QueryValue),
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) QueryRow {
        return QueryRow{
            .variables = std.StringHashMap(QueryValue).init(allocator),
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *QueryRow) void {
        self.variables.deinit();
    }

    pub fn set_variable(self: *QueryRow, name: []const u8, value: QueryValue) !void {
        try self.variables.put(name, value);
    }

    pub fn get_variable(self: *const QueryRow, name: []const u8) ?QueryValue {
        return self.variables.get(name);
    }

    pub fn copy_from(self: *QueryRow, other: *const QueryRow) !void {
        var it = other.variables.iterator();
        while (it.next()) |entry| {
            try self.variables.put(entry.key_ptr.*, entry.value_ptr.*);
        }
    }

    pub fn format(self: *const QueryRow, writer: anytype) !void {
        var it = self.variables.iterator();
        while (it.next()) |entry| {
            try writer.print("  {s} = {}\n", .{ entry.key_ptr.*, entry.value_ptr.* });
        }
    }
};

pub const QueryValue = union(enum) {
    node: nendb.Node,
    edge: nendb.Edge,
    integer: i64,
    float: f64,
    string: []const u8,
    boolean: bool,
    list: std.ArrayList(QueryValue),
    null,

    pub fn format(self: QueryValue, comptime fmt: []const u8, options: std.fmt.FormatOptions, writer: anytype) !void {
        _ = fmt;
        _ = options;
        switch (self) {
            .node => |node| try writer.print("Node(id={}, kind={})", .{ node.id, node.kind }),
            .edge => |edge| try writer.print("Edge({}->{}, label={})", .{ edge.from, edge.to, edge.label }),
            .integer => |i| try writer.print("{}", .{i}),
            .float => |f| try writer.print("{d}", .{f}),
            .string => |s| try writer.print("\"{s}\"", .{s}),
            .boolean => |b| try writer.print("{}", .{b}),
            .list => |list| {
                try writer.writeAll("[");
                for (list.items, 0..) |item, i| {
                    if (i > 0) try writer.writeAll(", ");
                    try item.format("", .{}, writer);
                }
                try writer.writeAll("]");
            },
            .null => try writer.print("null", .{}),
        }
    }
};
