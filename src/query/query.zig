// NenDB Query Language
// Cypher-like query language for graph operations

const std = @import("std");

pub const QueryResult = struct {
    rows: []const u8,
    count: usize,
};

// AST node types for query parsing
const Ast = union(enum) {
    Match: struct {
        pattern: Pattern,
        where: ?Expr,
        ret: ReturnFields,
        algorithm: ?[]const u8 = null, // BFS, DIJKSTRA, PAGERANK
    },
    Create: struct {
        entity: Entity,
    },
    Delete: struct {
        entity: Entity,
    },
    Set: struct {
        var_name: []const u8,
        key: []const u8,
        value: []const u8,
    },
};

const Pattern = struct {
    node: ?NodePattern = null,
    edge: ?EdgePattern = null,
};

const NodePattern = struct {
    var_name: []const u8,
    label: ?[]const u8 = null, // :Label
    props: ?[]const Property = null,
};

const EdgePattern = struct {
    from: []const u8,
    to: []const u8,
    var_name: ?[]const u8 = null, // variable between brackets
    rel_type: ?[]const u8 = null, // relationship type after ':'
};

const Property = struct {
    key: []const u8,
    value: []const u8,
};

const Expr = struct {
    var_name: []const u8,
    key: []const u8,
    value: []const u8,
};

const ReturnFields = struct {
    fields: []const []const u8,
};

const Entity = struct {
    var_name: []const u8,
    label: ?[]const u8 = null,
    props: ?[]const Property = null,
};

// Query parser
pub fn parse_query(query_str: []const u8, allocator: std.mem.Allocator) !Ast {
    var it = std.mem.tokenizeAny(u8, query_str, " \n\t");
    const first = it.next() orelse return error.EmptyQuery;

    if (std.mem.eql(u8, first, "MATCH")) {
        return try parse_match_query(&it, allocator);
    } else if (std.mem.eql(u8, first, "CREATE")) {
        return try parse_create_query(&it, allocator);
    } else if (std.mem.eql(u8, first, "DELETE")) {
        return try parse_delete_query(&it, allocator);
    } else if (std.mem.eql(u8, first, "SET")) {
        return try parse_set_query(&it, allocator);
    } else {
        return error.UnknownQuery;
    }
}

fn parse_match_query(it: *std.mem.TokenIterator(u8, std.mem.DelimiterType.any), allocator: std.mem.Allocator) !Ast {
    const pattern_token = it.next() orelse return error.InvalidQuery;

    // Check for edge pattern: (a)-[e]->(b)
    if (pattern_token[0] == '(' and std.mem.indexOf(u8, pattern_token, ")-") != null) {
        // Parse edge pattern
        const a_end = std.mem.indexOf(u8, pattern_token, ")") orelse return error.InvalidPattern;
        const a_var = pattern_token[1..a_end];

        const bracket_start = std.mem.indexOf(u8, pattern_token, "[") orelse return error.InvalidPattern;
        const bracket_end = std.mem.indexOf(u8, pattern_token, "]") orelse return error.InvalidPattern;
        const e_content = pattern_token[bracket_start + 1 .. bracket_end];
        var e_var: ?[]const u8 = null;
        var rel_type: ?[]const u8 = null;
        if (std.mem.indexOfScalar(u8, e_content, ':')) |colon_idx| {
            const before = std.mem.trim(u8, e_content[0..colon_idx], " ");
            const after = std.mem.trim(u8, e_content[colon_idx + 1 ..], " ");
            if (before.len > 0) e_var = before;
            if (after.len > 0) rel_type = after;
        } else if (e_content.len > 0) {
            e_var = e_content;
        }

        const b_start = std.mem.lastIndexOf(u8, pattern_token, "(") orelse return error.InvalidPattern;
        const b_end = std.mem.lastIndexOf(u8, pattern_token, ")") orelse return error.InvalidPattern;
        const b_var = pattern_token[b_start + 1 .. b_end];

        var algo: ?[]const u8 = null;
        var next_token = it.next() orelse return error.MissingReturn;

        // Check for USING clause
        if (std.mem.eql(u8, next_token, "USING")) {
            algo = it.next() orelse return error.InvalidAlgorithm;
            next_token = it.next() orelse return error.MissingReturn;
        }

        // Expect RETURN
        if (!std.mem.eql(u8, next_token, "RETURN")) return error.MissingReturn;

        const fields_token = it.next() orelse return error.InvalidReturn;
        const fields = try parse_return_fields(fields_token, allocator);

        return Ast{ .Match = .{
            .pattern = Pattern{ .edge = EdgePattern{ .from = a_var, .to = b_var, .var_name = e_var, .rel_type = rel_type } },
            .where = null,
            .ret = ReturnFields{ .fields = fields },
            .algorithm = algo,
        } };
    } else if (pattern_token[0] == '(' and pattern_token[pattern_token.len - 1] == ')') {
        // Parse node pattern: (n)
        const inner = pattern_token[1 .. pattern_token.len - 1];
        var var_name: []const u8 = inner;
        var label: ?[]const u8 = null;
        if (std.mem.indexOfScalar(u8, inner, ':')) |colon_idx| {
            var_name = inner[0..colon_idx];
            label = inner[colon_idx + 1 ..];
        }
        var where_expr: ?Expr = null;
        var algo: ?[]const u8 = null;

        var next_token = it.next() orelse return error.MissingReturn;

        // Check for USING clause
        if (std.mem.eql(u8, next_token, "USING")) {
            algo = it.next() orelse return error.InvalidAlgorithm;
            next_token = it.next() orelse return error.MissingReturn;
        }

        // Check for WHERE clause
        if (std.mem.eql(u8, next_token, "WHERE")) {
            const where_var = it.next() orelse return error.InvalidWhere;
            const key_token = it.next() orelse return error.InvalidWhere;
            if (key_token[0] != '.') return error.InvalidWhere;
            const key = key_token[1..];

            const eq_token = it.next() orelse return error.InvalidWhere;
            if (!std.mem.eql(u8, eq_token, "=")) return error.InvalidWhere;

            const value = it.next() orelse return error.InvalidWhere;
            where_expr = Expr{ .var_name = where_var, .key = key, .value = value };
            next_token = it.next() orelse return error.MissingReturn;
        }

        // Expect RETURN
        if (!std.mem.eql(u8, next_token, "RETURN")) return error.MissingReturn;

        const fields_token = it.next() orelse return error.InvalidReturn;
        const fields = try parse_return_fields(fields_token, allocator);

        return Ast{ .Match = .{
            .pattern = Pattern{ .node = NodePattern{ .var_name = var_name, .label = label, .props = null } },
            .where = where_expr,
            .ret = ReturnFields{ .fields = fields },
            .algorithm = algo,
        } };
    } else {
        return error.InvalidPattern;
    }
}

fn parse_create_query(it: *std.mem.TokenIterator(u8, std.mem.DelimiterType.any), allocator: std.mem.Allocator) !Ast {
    const pattern_token = it.next() orelse return error.InvalidCreate;

    if (pattern_token[0] != '(' or pattern_token[pattern_token.len - 1] != ')') {
        return error.InvalidPattern;
    }

    const inside = pattern_token[1 .. pattern_token.len - 1];
    const brace_idx = std.mem.indexOfScalar(u8, inside, '{') orelse return error.InvalidCreate;
    const header = std.mem.trim(u8, inside[0..brace_idx], " ");
    var var_name = header;
    var label: ?[]const u8 = null;
    if (std.mem.indexOfScalar(u8, header, ':')) |colon_idx| {
        var_name = std.mem.trim(u8, header[0..colon_idx], " ");
        const after = std.mem.trim(u8, header[colon_idx + 1 ..], " ");
        if (after.len > 0) label = after;
    }
    const props_str = std.mem.trim(u8, inside[brace_idx + 1 .. inside.len - 1], " }");

    var props = std.ArrayList(Property).init(allocator);
    defer props.deinit();

    var prop_it = std.mem.tokenizeAny(u8, props_str, ",");
    while (prop_it.next()) |prop| {
        var kv = std.mem.tokenizeAny(u8, prop, ":");
        const key = std.mem.trim(u8, kv.next() orelse continue, " \"");
        const value = std.mem.trim(u8, kv.next() orelse continue, " \"");
        try props.append(Property{ .key = key, .value = value });
    }

    return Ast{ .Create = .{
        .entity = Entity{ .var_name = var_name, .label = label, .props = try props.toOwnedSlice() },
    } };
}

fn parse_delete_query(it: *std.mem.TokenIterator(u8, std.mem.DelimiterType.any), allocator: std.mem.Allocator) !Ast {
    _ = allocator; // Future use
    const pattern_token = it.next() orelse return error.InvalidDelete;

    if (pattern_token[0] != '(' or pattern_token[pattern_token.len - 1] != ')') {
        return error.InvalidPattern;
    }

    const var_name = pattern_token[1 .. pattern_token.len - 1];
    return Ast{ .Delete = .{
        .entity = Entity{ .var_name = var_name, .props = null },
    } };
}

fn parse_set_query(it: *std.mem.TokenIterator(u8, std.mem.DelimiterType.any), allocator: std.mem.Allocator) !Ast {
    _ = allocator; // Future use
    const var_key = it.next() orelse return error.InvalidSet;
    const dot_idx = std.mem.indexOfScalar(u8, var_key, '.') orelse return error.InvalidSet;
    const var_name = var_key[0..dot_idx];
    const key = var_key[dot_idx + 1 ..];

    const eq_token = it.next() orelse return error.InvalidSet;
    if (!std.mem.eql(u8, eq_token, "=")) return error.InvalidSet;

    const value = it.next() orelse return error.InvalidSet;

    return Ast{ .Set = .{
        .var_name = var_name,
        .key = key,
        .value = value,
    } };
}

fn parse_return_fields(fields_token: []const u8, allocator: std.mem.Allocator) ![][]const u8 {
    var fields = std.ArrayList([]const u8).init(allocator);
    defer fields.deinit();

    var field_it = std.mem.tokenizeAny(u8, fields_token, ",");
    while (field_it.next()) |field| {
        try fields.append(std.mem.trim(u8, field, " "));
    }

    return fields.toOwnedSlice();
}

// Query examples and documentation
pub const QUERY_EXAMPLES = [_][]const u8{
    "MATCH (n) RETURN n",
    "MATCH (n) WHERE n.kind = 1 RETURN n",
    "MATCH (a)-[e]->(b) RETURN a, b",
    "MATCH (n) USING BFS RETURN n",
    "CREATE (user {id: \"alice\", kind: 0})",
    "DELETE (n)",
    "SET n.kind = 2",
};

pub const SUPPORTED_ALGORITHMS = [_][]const u8{
    "BFS", // Breadth-first search
    "DFS", // Depth-first search
    "DIJKSTRA", // Shortest path
    "PAGERANK", // Page rank algorithm
    "CENTRALITY", // Centrality measures
};
