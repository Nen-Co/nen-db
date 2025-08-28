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
        var parts = std.ArrayList(ast.Part).init(self.allocator);
        defer parts.deinit();

        var clauses = std.ArrayList(ast.Clause).init(self.allocator);
        defer clauses.deinit();

        while (true) {
            // OPTIONAL MATCH
            if (self.current.kind == .keyword and std.ascii.eqlIgnoreCase(self.current.lexeme, "OPTIONAL")) {
                self.advance();
                const m = try self.parseMatch(true);
                try clauses.append(ast.Clause{ .OptionalMatch = m });
                continue;
            }
            if (self.current.kind == .keyword and std.ascii.eqlIgnoreCase(self.current.lexeme, "MATCH")) {
                const m = try self.parseMatch(false);
                try clauses.append(ast.Clause{ .Match = m });
                continue;
            }
            if (self.current.kind == .keyword and std.ascii.eqlIgnoreCase(self.current.lexeme, "UNWIND")) {
                const u = try self.parseUnwind();
                try clauses.append(ast.Clause{ .Unwind = u });
                continue;
            }
            if (self.current.kind == .keyword and std.ascii.eqlIgnoreCase(self.current.lexeme, "SET")) {
                const s = try self.parseSet();
                try clauses.append(ast.Clause{ .Set = s });
                continue;
            }
            if (self.current.kind == .keyword and std.ascii.eqlIgnoreCase(self.current.lexeme, "DELETE")) {
                const d = try self.parseDelete(false);
                try clauses.append(ast.Clause{ .Delete = d });
                continue;
            }
            if (self.current.kind == .keyword and std.ascii.eqlIgnoreCase(self.current.lexeme, "DETACH")) {
                self.advance();
                try self.expectKeyword("DELETE");
                const d = try self.parseDelete(true);
                try clauses.append(ast.Clause{ .DetachDelete = d });
                continue;
            }
            if (self.current.kind == .keyword and std.ascii.eqlIgnoreCase(self.current.lexeme, "WITH")) {
                const w = try self.parseWith();
                try clauses.append(ast.Clause{ .With = w });
                // Start a new part after WITH
                try parts.append(.{ .clauses = try clauses.toOwnedSlice() });
                clauses = std.ArrayList(ast.Clause).init(self.allocator);
                continue;
            }
            if (self.current.kind == .keyword and std.ascii.eqlIgnoreCase(self.current.lexeme, "RETURN")) {
                const r = try self.parseReturn();
                try clauses.append(ast.Clause{ .Return = r });
                // finalize last part
                try parts.append(.{ .clauses = try clauses.toOwnedSlice() });
                clauses = std.ArrayList(ast.Clause).init(self.allocator);
                break;
            }
            if (self.current.kind == .eof) break;
            // For skeleton: stop to avoid infinite loop
            break;
        }

        if (clauses.items.len > 0) {
            try parts.append(.{ .clauses = try clauses.toOwnedSlice() });
        }

        return .{ .query = .{ .parts = try parts.toOwnedSlice() } };
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
        var labels = std.ArrayList([]const u8).init(self.allocator);
        defer labels.deinit();
        while (self.current.kind == .colon) {
            self.advance();
            if (self.current.kind != .identifier) return error.ExpectedLabel;
            try labels.append(self.current.lexeme);
            self.advance();
        }
        var props: ?ast.MapLiteral = null;
        if (self.current.kind == .l_brace) {
            props = try self.parseMapLiteral();
        }
        if (self.current.kind != .r_paren) return error.ExpectedRParen;
        self.advance();
        return .{ .variable = variable, .labels = try labels.toOwnedSlice(), .properties = props };
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
        var types = std.ArrayList([]const u8).init(self.allocator);
        defer types.deinit();
        if (self.current.kind == .colon) {
            self.advance();
            if (self.current.kind != .identifier) return error.ExpectedType;
            try types.append(self.current.lexeme);
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
                return .{ .variable = variable, .types = try types.toOwnedSlice(), .direction = .right, .min_hops = null, .max_hops = null, .properties = props };
            }
        }
        return .{ .variable = variable, .types = try types.toOwnedSlice(), .direction = .undirected, .min_hops = null, .max_hops = null, .properties = props };
    }

    fn parseMapLiteral(self: *Parser) !ast.MapLiteral {
        if (self.current.kind != .l_brace) return error.ExpectedLBrace;
        self.advance();
        var entries = std.ArrayList(ast.MapEntry).init(self.allocator);
        defer entries.deinit();
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
            try entries.append(.{ .key = key, .value = value });
        }
        self.advance(); // r_brace
        return .{ .entries = try entries.toOwnedSlice() };
    }

    fn parsePrimaryExpr(self: *Parser) !ast.Expression {
        switch (self.current.kind) {
            .identifier => {
                const name = self.current.lexeme;
                self.advance();
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

    fn parseEqExpr(self: *Parser) !ast.Expression {
        const left = try self.parsePrimaryExpr();
        if (self.current.kind != .eq) return error.ExpectedEq;
        self.advance();
        const right = try self.parsePrimaryExpr();
        // Allocate nodes for union recursion
        const left_box = try self.allocator.create(ast.Expression);
        left_box.* = left;
        const right_box = try self.allocator.create(ast.Expression);
        right_box.* = right;
        return .{ .eq = .{ .left = left_box, .right = right_box } };
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
