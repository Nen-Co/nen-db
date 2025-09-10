const std = @import("std");
const TokenKind = @import("lexer.zig").TokenKind;
const Token = @import("lexer.zig").Token;
const Lexer = @import("lexer.zig").Lexer;
const ast = @import("ast.zig");

pub const Parser = struct {
    allocator: std.mem.Allocator,
    lexer: Lexer,
    current: Token,

    pub fn init(allocator: std.mem.Allocator, input: []const u8) Parser {
        var p = Parser{
            .allocator = allocator,
            .lexer = Lexer.init(input),
            .current = .{ .kind = .invalid, .lexeme = input[0..0] },
        };
        p.advance();
        return p;
    }

    fn advance(self: *Parser) void {
        self.current = self.lexer.next();
    }

    fn expectKeyword(self: *Parser, kw: []const u8) !void {
        if (self.current.kind != .keyword or !std.ascii.eqlIgnoreCase(self.current.lexeme, kw))
            return error.UnexpectedToken;
        self.advance();
    }

    pub fn parseQuery(self: *Parser) !ast.Statement {
        // Very minimal sequence: (MATCH ...)* (WITH ...)* (RETURN ...)? etc.
        // Use unmanaged lists to align with Zig 0.15.1 container changes.
        var parts: std.ArrayListUnmanaged(ast.Part) = .{};
        defer parts.deinit(self.allocator);

        var clauses: std.ArrayListUnmanaged(ast.Clause) = .{};
        defer clauses.deinit(self.allocator);

        while (true) {
            // OPTIONAL MATCH
            if (self.current.kind == .keyword and std.ascii.eqlIgnoreCase(self.current.lexeme, "OPTIONAL")) {
                self.advance();
                const m = try self.parseMatch(true);
                try clauses.append(self.allocator, ast.Clause{ .OptionalMatch = m });
                continue;
            }
            if (self.current.kind == .keyword and std.ascii.eqlIgnoreCase(self.current.lexeme, "MATCH")) {
                const m = try self.parseMatch(false);
                try clauses.append(self.allocator, ast.Clause{ .Match = m });
                continue;
            }
            if (self.current.kind == .keyword and std.ascii.eqlIgnoreCase(self.current.lexeme, "UNWIND")) {
                const u = try self.parseUnwind();
                try clauses.append(self.allocator, ast.Clause{ .Unwind = u });
                continue;
            }
            if (self.current.kind == .keyword and std.ascii.eqlIgnoreCase(self.current.lexeme, "SET")) {
                const s = try self.parseSet();
                try clauses.append(self.allocator, ast.Clause{ .Set = s });
                continue;
            }
            if (self.current.kind == .keyword and std.ascii.eqlIgnoreCase(self.current.lexeme, "DELETE")) {
                const d = try self.parseDelete(false);
                try clauses.append(self.allocator, ast.Clause{ .Delete = d });
                continue;
            }
            if (self.current.kind == .keyword and std.ascii.eqlIgnoreCase(self.current.lexeme, "DETACH")) {
                self.advance();
                try self.expectKeyword("DELETE");
                const d = try self.parseDelete(true);
                try clauses.append(self.allocator, ast.Clause{ .DetachDelete = d });
                continue;
            }
            if (self.current.kind == .keyword and std.ascii.eqlIgnoreCase(self.current.lexeme, "WITH")) {
                const w = try self.parseWith();
                try clauses.append(self.allocator, ast.Clause{ .With = w });
                // Start a new part after WITH
                try parts.append(self.allocator, .{ .clauses = try clauses.toOwnedSlice(self.allocator) });
                // Reset clauses list (previous buffer released by toOwnedSlice allocation copy).
                clauses = .{};
                continue;
            }
            if (self.current.kind == .keyword and std.ascii.eqlIgnoreCase(self.current.lexeme, "RETURN")) {
                const r = try self.parseReturn();
                try clauses.append(self.allocator, ast.Clause{ .Return = r });
                // finalize last part
                try parts.append(self.allocator, .{ .clauses = try clauses.toOwnedSlice(self.allocator) });
                clauses = .{};
                break;
            }
            if (self.current.kind == .eof) break;
            // For skeleton: stop to avoid infinite loop
            break;
        }

        if (clauses.items.len > 0) {
            try parts.append(self.allocator, .{ .clauses = try clauses.toOwnedSlice(self.allocator) });
        }

        return .{ .query = .{ .parts = try parts.toOwnedSlice(self.allocator) } };
    }

    fn parseMatch(self: *Parser, optional: bool) !ast.Match {
        try self.expectKeyword("MATCH");
        const pattern = try self.parsePattern();
        var where_expr: ?ast.Expression = null;
        if (self.current.kind == .keyword and std.ascii.eqlIgnoreCase(self.current.lexeme, "WHERE")) {
            self.advance();
            where_expr = try self.parseEqExpr();
        }
        return .{ .optional = optional, .pattern = pattern, .where = where_expr };
    }

    fn parseReturn(self: *Parser) !ast.Return {
        try self.expectKeyword("RETURN");
        // For skeleton: accept return items but do not retain them to avoid allocations
        if (self.current.kind != .eof and self.current.kind != .keyword) {
            _ = try self.parsePrimaryExpr();
            while (self.current.kind == .comma) {
                self.advance();
                _ = try self.parsePrimaryExpr();
            }
        }
        var order_by: ?ast.OrderBy = null;
        if (self.current.kind == .keyword and std.ascii.eqlIgnoreCase(self.current.lexeme, "ORDER")) {
            self.advance();
            try self.expectKeyword("BY");
            order_by = try self.parseOrderBy();
        }
        var skip_limit: ?ast.SkipLimit = null;
        var skip_val: ?usize = null;
        var limit_val: ?usize = null;
        if (self.current.kind == .keyword and std.ascii.eqlIgnoreCase(self.current.lexeme, "SKIP")) {
            self.advance();
            if (self.current.kind != .integer) return error.ExpectedInteger;
            skip_val = std.fmt.parseInt(usize, self.current.lexeme, 10) catch 0;
            self.advance();
        }
        if (self.current.kind == .keyword and std.ascii.eqlIgnoreCase(self.current.lexeme, "LIMIT")) {
            self.advance();
            if (self.current.kind != .integer) return error.ExpectedInteger;
            limit_val = std.fmt.parseInt(usize, self.current.lexeme, 10) catch 0;
            self.advance();
        }
        if (skip_val != null or limit_val != null) {
            skip_limit = ast.SkipLimit{ .skip = skip_val, .limit = limit_val };
        }
        return .{ .distinct = false, .items = &[_]ast.ReturnItem{}, .order_by = order_by, .skip_limit = skip_limit };
    }

    fn parseWith(self: *Parser) !ast.With {
        try self.expectKeyword("WITH");
        // For skeleton: accept items but do not retain allocations
        if (self.current.kind != .eof and self.current.kind != .keyword) {
            _ = try self.parsePrimaryExpr();
            while (self.current.kind == .comma) {
                self.advance();
                _ = try self.parsePrimaryExpr();
            }
        }
        var order_by: ?ast.OrderBy = null;
        if (self.current.kind == .keyword and std.ascii.eqlIgnoreCase(self.current.lexeme, "ORDER")) {
            self.advance();
            try self.expectKeyword("BY");
            order_by = try self.parseOrderBy();
        }
        var skip_limit: ?ast.SkipLimit = null;
        var skip_val: ?usize = null;
        var limit_val: ?usize = null;
        if (self.current.kind == .keyword and std.ascii.eqlIgnoreCase(self.current.lexeme, "SKIP")) {
            self.advance();
            if (self.current.kind != .integer) return error.ExpectedInteger;
            skip_val = std.fmt.parseInt(usize, self.current.lexeme, 10) catch 0;
            self.advance();
        }
        if (self.current.kind == .keyword and std.ascii.eqlIgnoreCase(self.current.lexeme, "LIMIT")) {
            self.advance();
            if (self.current.kind != .integer) return error.ExpectedInteger;
            limit_val = std.fmt.parseInt(usize, self.current.lexeme, 10) catch 0;
            self.advance();
        }
        if (skip_val != null or limit_val != null) {
            skip_limit = ast.SkipLimit{ .skip = skip_val, .limit = limit_val };
        }
        return .{ .items = &[_]ast.ReturnItem{}, .where = null, .order_by = order_by, .skip_limit = skip_limit };
    }

    fn parseOrderBy(self: *Parser) !ast.OrderBy {
        // Skeleton: parse expressions but do not store
        if (self.current.kind != .eof) {
            _ = try self.parsePrimaryExpr();
            if (self.current.kind == .keyword and (std.ascii.eqlIgnoreCase(self.current.lexeme, "DESC") or std.ascii.eqlIgnoreCase(self.current.lexeme, "ASC"))) self.advance();
            while (self.current.kind == .comma) {
                self.advance();
                _ = try self.parsePrimaryExpr();
                if (self.current.kind == .keyword and (std.ascii.eqlIgnoreCase(self.current.lexeme, "DESC") or std.ascii.eqlIgnoreCase(self.current.lexeme, "ASC"))) self.advance();
            }
        }
        return .{ .items = &[_]ast.SortItem{} };
    }

    fn parseUnwind(self: *Parser) !ast.Unwind {
        try self.expectKeyword("UNWIND");
        const expr = try self.parsePrimaryExpr();
        try self.expectKeyword("AS");
        if (self.current.kind != .identifier) return error.ExpectedIdentifier;
        const alias = self.current.lexeme;
        self.advance();
        return .{ .expr = expr, .alias = alias };
    }

    fn parseSet(self: *Parser) !ast.Set {
        // Skeleton: parse assignments but do not retain allocations
        try self.expectKeyword("SET");
        // minimal: n.key = value {, n.key = value}*
        var first = true;
        while (true) {
            if (!first) {
                if (self.current.kind == .comma) self.advance() else break;
            }
            first = false;
            // target
            if (self.current.kind != .identifier) return error.ExpectedIdentifier;
            const var_name = self.current.lexeme;
            self.advance();
            if (self.current.kind != .dot) return error.ExpectedDot;
            self.advance();
            if (self.current.kind != .identifier) return error.ExpectedPropertyKey;
            const key = self.current.lexeme;
            self.advance();
            if (self.current.kind != .eq) return error.ExpectedEq;
            self.advance();
            const value = try self.parsePrimaryExpr();
            _ = var_name;
            _ = key;
            _ = value;
        }
        return .{ .items = &[_]ast.SetItem{} };
    }

    fn parseDelete(self: *Parser, detach: bool) !ast.Delete {
        // Skeleton: consume a single token or comma-separated identifiers without building expressions
        if (self.current.kind != .eof and self.current.kind != .comma) {
            self.advance();
        }
        while (self.current.kind == .comma) {
            self.advance();
            if (self.current.kind == .eof) break;
            self.advance();
        }
        return .{ .detach = detach, .expressions = &[_]ast.Expression{} };
    }

    fn parsePattern(self: *Parser) !ast.Pattern {
        // minimal: (n) or (a)-[r]->(b) but do not retain allocations in skeleton
        _ = try self.parsePath();
        return .{ .paths = &[_]ast.Path{} };
    }

    fn parsePath(self: *Parser) !ast.Path {
        _ = try self.parseNodePattern();
        if (self.current.kind == .minus) {
            _ = try self.parseRelationshipPattern();
            _ = try self.parseNodePattern();
        }
        return .{ .elements = &[_]ast.PathElement{} };
    }

    fn parseNodePattern(self: *Parser) !ast.NodePattern {
        if (self.current.kind != .l_paren) return error.ExpectedNodeStart;
        self.advance();
        var variable: ?[]const u8 = null;
        if (self.current.kind == .identifier) {
            variable = self.current.lexeme;
            self.advance();
        }
        var labels: std.ArrayListUnmanaged([]const u8) = .{};
        defer labels.deinit(self.allocator);
        while (self.current.kind == .colon) {
            self.advance();
            if (self.current.kind != .identifier) return error.ExpectedLabel;
            try labels.append(self.allocator, self.current.lexeme);
            self.advance();
        }
        var props: ?ast.MapLiteral = null;
        if (self.current.kind == .l_brace) {
            props = try self.parseMapLiteral();
        }
        if (self.current.kind != .r_paren) return error.ExpectedRParen;
        self.advance();
        return .{ .variable = variable, .labels = try labels.toOwnedSlice(self.allocator), .properties = props };
    }

    fn parseRelationshipPattern(self: *Parser) !ast.RelationshipPattern {
        // pattern: -[r:TYPE]-> or <-[r:TYPE]-
        if (self.current.kind != .minus) return error.ExpectedMinus;
        self.advance();
        if (self.current.kind != .l_brack) return error.ExpectedLBrack;
        self.advance();
        var variable: ?[]const u8 = null;
        if (self.current.kind == .identifier) {
            variable = self.current.lexeme;
            self.advance();
        }
        var types: std.ArrayListUnmanaged([]const u8) = .{};
        defer types.deinit(self.allocator);
        if (self.current.kind == .colon) {
            self.advance();
            if (self.current.kind != .identifier) return error.ExpectedType;
            try types.append(self.allocator, self.current.lexeme);
            self.advance();
        }
        var props: ?ast.MapLiteral = null;
        if (self.current.kind == .l_brace) {
            props = try self.parseMapLiteral();
        }
        if (self.current.kind != .r_brack) return error.ExpectedRBrack;
        self.advance();
        // Minimal direction handling: treat '-[...] ->' as right; others as undirected for now.
        if (self.current.kind == .minus) {
            self.advance();
            if (self.current.kind == .gt) {
                self.advance();
                return .{ .variable = variable, .types = try types.toOwnedSlice(self.allocator), .direction = .right, .min_hops = null, .max_hops = null, .properties = props };
            }
        }
        return .{ .variable = variable, .types = try types.toOwnedSlice(self.allocator), .direction = .undirected, .min_hops = null, .max_hops = null, .properties = props };
    }

    fn parseMapLiteral(self: *Parser) !ast.MapLiteral {
        if (self.current.kind != .l_brace) return error.ExpectedLBrace;
        self.advance();
        var entries: std.ArrayListUnmanaged(ast.MapEntry) = .{};
        defer entries.deinit(self.allocator);
        var first = true;
        while (self.current.kind != .r_brace) {
            if (!first) {
                if (self.current.kind != .comma) return error.ExpectedComma;
                self.advance();
            }
            first = false;
            if (self.current.kind != .identifier) return error.ExpectedMapKey;
            const key = self.current.lexeme;
            self.advance();
            if (self.current.kind != .colon) return error.ExpectedColon;
            self.advance();
            // Primitive-only to avoid recursion cycles for now
            const value = switch (self.current.kind) {
                .string => blk: {
                    const s = self.current.lexeme;
                    self.advance();
                    break :blk ast.Expression{ .string = s };
                },
                .integer => blk: {
                    const v = std.fmt.parseInt(i64, self.current.lexeme, 10) catch 0;
                    self.advance();
                    break :blk ast.Expression{ .integer = v };
                },
                .float => blk: {
                    const v = std.fmt.parseFloat(f64, self.current.lexeme) catch 0;
                    self.advance();
                    break :blk ast.Expression{ .float = v };
                },
                .identifier => blk: {
                    const n = self.current.lexeme;
                    self.advance();
                    break :blk ast.Expression{ .variable = n };
                },
                else => return error.UnexpectedExpr,
            };
            try entries.append(self.allocator, .{ .key = key, .value = value });
        }
        self.advance(); // r_brace
        return .{ .entries = try entries.toOwnedSlice(self.allocator) };
    }

    fn parsePrimaryExpr(self: *Parser) !ast.Expression {
        switch (self.current.kind) {
            .identifier => {
                const name = self.current.lexeme;
                self.advance();

                // Check for function call
                if (self.current.kind == .l_paren) {
                    return try self.parseFunctionCall(name);
                }

                // Check for property access
                if (self.current.kind == .dot) {
                    self.advance();
                    if (self.current.kind != .identifier) return error.ExpectedPropertyKey;
                    // Skip allocating keys in skeleton to avoid leaks when not retained
                    self.advance();
                    return .{ .property = .{ .variable = name, .keys = &[_][]const u8{} } };
                }

                return .{ .variable = name };
            },
            .string => {
                const s = self.current.lexeme;
                self.advance();
                return .{ .string = s };
            },
            .integer => {
                const val = std.fmt.parseInt(i64, self.current.lexeme, 10) catch 0;
                self.advance();
                return .{ .integer = val };
            },
            .float => {
                const val = std.fmt.parseFloat(f64, self.current.lexeme) catch 0;
                self.advance();
                return .{ .float = val };
            },
            .l_brack => {
                const list = try parseListLiteral(self);
                return .{ .list = list };
            },
            .l_brace => return error.UnexpectedExpr,
            else => return error.UnexpectedExpr,
        }
    }

    fn parseFunctionCall(self: *Parser, func_name: []const u8) !ast.Expression {
        self.advance(); // consume (

        // For now, just consume the arguments without parsing them
        var paren_count: u32 = 1;
        while (self.current.kind != .eof and paren_count > 0) {
            switch (self.current.kind) {
                .l_paren => paren_count += 1,
                .r_paren => paren_count -= 1,
                else => {},
            }
            self.advance();
        }

        // Handle different function types (simplified for now)
        if (std.ascii.eqlIgnoreCase(func_name, "COUNT")) {
            return .{ .count = .{ .expr = try self.allocator.create(ast.Expression), .distinct = false } };
        } else if (std.ascii.eqlIgnoreCase(func_name, "SUM")) {
            return .{ .sum = .{ .expr = try self.allocator.create(ast.Expression) } };
        } else if (std.ascii.eqlIgnoreCase(func_name, "AVG")) {
            return .{ .avg = .{ .expr = try self.allocator.create(ast.Expression) } };
        } else if (std.ascii.eqlIgnoreCase(func_name, "MIN")) {
            return .{ .min = .{ .expr = try self.allocator.create(ast.Expression) } };
        } else if (std.ascii.eqlIgnoreCase(func_name, "MAX")) {
            return .{ .max = .{ .expr = try self.allocator.create(ast.Expression) } };
        } else if (std.ascii.eqlIgnoreCase(func_name, "TOUPPER")) {
            return .{ .toUpper = .{ .expr = try self.allocator.create(ast.Expression) } };
        } else if (std.ascii.eqlIgnoreCase(func_name, "TOLOWER")) {
            return .{ .toLower = .{ .expr = try self.allocator.create(ast.Expression) } };
        } else if (std.ascii.eqlIgnoreCase(func_name, "TRIM")) {
            return .{ .trim = .{ .expr = try self.allocator.create(ast.Expression) } };
        } else if (std.ascii.eqlIgnoreCase(func_name, "ABS")) {
            return .{ .abs = .{ .expr = try self.allocator.create(ast.Expression) } };
        } else if (std.ascii.eqlIgnoreCase(func_name, "ROUND")) {
            return .{ .round = .{ .expr = try self.allocator.create(ast.Expression) } };
        } else if (std.ascii.eqlIgnoreCase(func_name, "CEIL")) {
            return .{ .ceil = .{ .expr = try self.allocator.create(ast.Expression) } };
        } else if (std.ascii.eqlIgnoreCase(func_name, "FLOOR")) {
            return .{ .floor = .{ .expr = try self.allocator.create(ast.Expression) } };
        } else if (std.ascii.eqlIgnoreCase(func_name, "SQRT")) {
            return .{ .sqrt = .{ .expr = try self.allocator.create(ast.Expression) } };
        }

        // Unknown function - return as variable for now
        return .{ .variable = func_name };
    }

    fn parseEqExpr(self: *Parser) !ast.Expression {
        return try self.parseLogicalOr();
    }

    // Operator precedence parsing (highest to lowest)
    fn parseLogicalOr(self: *Parser) !ast.Expression {
        var left = try self.parseLogicalAnd();

        while (self.current.kind == .keyword and std.ascii.eqlIgnoreCase(self.current.lexeme, "OR")) {
            self.advance();
            const right = try self.parseLogicalAnd();

            const left_box = try self.allocator.create(ast.Expression);
            left_box.* = left;
            const right_box = try self.allocator.create(ast.Expression);
            right_box.* = right;

            left = .{ .logical_or = .{ .left = left_box, .right = right_box } };
        }

        return left;
    }

    fn parseLogicalAnd(self: *Parser) !ast.Expression {
        var left = try self.parseEquality();

        while (self.current.kind == .keyword and std.ascii.eqlIgnoreCase(self.current.lexeme, "AND")) {
            self.advance();
            const right = try self.parseEquality();

            const left_box = try self.allocator.create(ast.Expression);
            left_box.* = left;
            const right_box = try self.allocator.create(ast.Expression);
            right_box.* = right;

            left = .{ .logical_and = .{ .left = left_box, .right = right_box } };
        }

        return left;
    }

    fn parseEquality(self: *Parser) !ast.Expression {
        var left = try self.parseComparison();

        while (self.current.kind == .eq) {
            self.advance();
            const right = try self.parseComparison();
            const left_box = try self.allocator.create(ast.Expression);
            left_box.* = left;
            const right_box = try self.allocator.create(ast.Expression);
            right_box.* = right;
            left = .{ .eq = .{ .left = left_box, .right = right_box } };
        }

        return left;
    }

    fn parseComparison(self: *Parser) !ast.Expression {
        var left = try self.parseAdditive();

        while (self.current.kind == .lt or self.current.kind == .gt) {
            const op_kind = self.current.kind;
            self.advance();

            // Check for <= or >= (simplified - we'll handle this in lexer later)
            const right = try self.parseAdditive();
            const left_box = try self.allocator.create(ast.Expression);
            left_box.* = left;
            const right_box = try self.allocator.create(ast.Expression);
            right_box.* = right;

            left = switch (op_kind) {
                .lt => .{ .lt = .{ .left = left_box, .right = right_box } },
                .gt => .{ .gt = .{ .left = left_box, .right = right_box } },
                else => unreachable,
            };
        }

        return left;
    }

    fn parseAdditive(self: *Parser) !ast.Expression {
        var left = try self.parseMultiplicative();

        while (self.current.kind == .plus or self.current.kind == .minus) {
            const op = self.current.kind;
            self.advance();
            const right = try self.parseMultiplicative();

            const left_box = try self.allocator.create(ast.Expression);
            left_box.* = left;
            const right_box = try self.allocator.create(ast.Expression);
            right_box.* = right;

            left = switch (op) {
                .plus => .{ .add = .{ .left = left_box, .right = right_box } },
                .minus => .{ .sub = .{ .left = left_box, .right = right_box } },
                else => unreachable,
            };
        }

        return left;
    }

    fn parseMultiplicative(self: *Parser) !ast.Expression {
        var left = try self.parseUnary();

        while (self.current.kind == .star or self.current.kind == .slash) {
            const op = self.current.kind;
            self.advance();
            const right = try self.parseUnary();

            const left_box = try self.allocator.create(ast.Expression);
            left_box.* = left;
            const right_box = try self.allocator.create(ast.Expression);
            right_box.* = right;

            left = switch (op) {
                .star => .{ .mul = .{ .left = left_box, .right = right_box } },
                .slash => .{ .div = .{ .left = left_box, .right = right_box } },
                else => unreachable,
            };
        }

        return left;
    }

    fn parseUnary(self: *Parser) !ast.Expression {
        if (self.current.kind == .keyword and std.ascii.eqlIgnoreCase(self.current.lexeme, "NOT")) {
            self.advance();
            const expr = try self.parseUnary();
            const expr_box = try self.allocator.create(ast.Expression);
            expr_box.* = expr;
            return .{ .logical_not = .{ .expr = expr_box } };
        }

        return try self.parsePrimaryExpr();
    }
};

fn parsePrimitiveExpr(self: *Parser) !ast.Expression {
    return switch (self.current.kind) {
        .string => blk: {
            const s = self.current.lexeme;
            self.advance();
            break :blk ast.Expression{ .string = s };
        },
        .integer => blk: {
            const val = std.fmt.parseInt(i64, self.current.lexeme, 10) catch 0;
            self.advance();
            break :blk ast.Expression{ .integer = val };
        },
        .float => blk: {
            const val = std.fmt.parseFloat(f64, self.current.lexeme) catch 0;
            self.advance();
            break :blk ast.Expression{ .float = val };
        },
        .identifier => blk: {
            const name = self.current.lexeme;
            self.advance();
            break :blk ast.Expression{ .variable = name };
        },
        else => error.UnexpectedExpr,
    };
}

fn parseListLiteral(self: *Parser) !ast.ListLiteral {
    if (self.current.kind != .l_brack) return error.ExpectedLBrack;
    self.advance();
    var first = true;
    while (self.current.kind != .r_brack) {
        if (!first) {
            if (self.current.kind != .comma) return error.ExpectedComma;
            self.advance();
        }
        first = false;
        _ = try parsePrimitiveExpr(self);
    }
    self.advance(); // r_brack
    return .{ .items = &[_]ast.Expression{} };
}
