const std = @import("std");

// High-level AST for openCypher v9 subset/superset we aim to support.

pub const Statement = union(enum) {
    query: Query,
};

pub const Query = struct {
    parts: []Part, // sequence of clause groups possibly separated by WITH
};

pub const Part = struct {
    clauses: []Clause,
};

pub const Clause = union(enum) {
    Match: Match,
    OptionalMatch: Match,
    With: With,
    Return: Return,
    Create: Create,
    Merge: Merge,
    Set: Set,
    Delete: Delete,
    DetachDelete: Delete,
    Unwind: Unwind,
    Remove: Remove,
    OrderBy: OrderBy,
    Skip: Skip,
    Limit: Limit,
    Using: Using,
};

pub const Match = struct {
    optional: bool,
    pattern: Pattern,
    where: ?Expression = null,
};

pub const With = struct {
    items: []ReturnItem,
    where: ?Expression = null,
    order_by: ?OrderBy = null,
    skip_limit: ?SkipLimit = null,
};

pub const Return = struct {
    distinct: bool,
    items: []ReturnItem,
    order_by: ?OrderBy = null,
    skip_limit: ?SkipLimit = null,
};

pub const ReturnItem = struct {
    expr: Expression,
    alias: ?[]const u8 = null,
};

pub const Create = struct { pattern: Pattern };
pub const Merge = struct { pattern: Pattern };
pub const Set = struct { items: []SetItem };
pub const Delete = struct { detach: bool, expressions: []Expression };
pub const Unwind = struct { expr: Expression, alias: []const u8 };
pub const Remove = struct { items: []PropertySelector };
pub const OrderBy = struct { items: []SortItem };
pub const Skip = struct { count: usize };
pub const Limit = struct { count: usize };
pub const Using = struct { hint: UsingHint };
pub const SkipLimit = struct { skip: ?usize, limit: ?usize };

pub const UsingHint = union(enum) {
    bfs,
    dfs,
    dijkstra,
    pagerank,
    centrality,
};

pub const SortItem = struct {
    expr: Expression,
    descending: bool = false,
};

pub const SetItem = union(enum) {
    property: struct { target: PropertySelector, value: Expression },
    map_merge: struct { variable: []const u8, map: MapLiteral },
};

pub const Pattern = struct {
    paths: []Path,
};

pub const Path = struct {
    elements: []PathElement,
};

pub const PathElement = union(enum) {
    node: NodePattern,
    relationship: RelationshipPattern,
};

pub const NodePattern = struct {
    variable: ?[]const u8 = null,
    labels: [][]const u8 = &[_][]const u8{},
    properties: ?MapLiteral = null,
};

pub const RelationshipPattern = struct {
    variable: ?[]const u8 = null,
    types: [][]const u8 = &[_][]const u8{},
    direction: enum { left, right, undirected } = .right,
    min_hops: ?usize = null,
    max_hops: ?usize = null,
    properties: ?MapLiteral = null,
};

pub const PropertySelector = struct {
    variable: []const u8,
    keys: [][]const u8,
};

// Common struct types for operators to avoid type incompatibility
pub const BinaryOperator = struct { left: *Expression, right: *Expression };
pub const UnaryOperator = struct { expr: *Expression };
pub const SubstringOperator = struct { expr: *Expression, start: *Expression, length: *Expression };
pub const CountOperator = struct { expr: *Expression, distinct: bool };

// Forward declarations needed for Expression union
pub const MapLiteral = struct {
    entries: []MapEntry,
};

pub const MapEntry = struct { key: []const u8, value: Expression };
pub const ListLiteral = struct { items: []Expression };

pub const Expression = union(enum) {
    // Primary
    variable: []const u8,
    property: PropertySelector,
    string: []const u8,
    integer: i64,
    float: f64,
    boolean: bool,
    null: void,
    map: MapLiteral,
    list: ListLiteral,
    
    // Comparison Operators
    eq: BinaryOperator,      // =
    ne: BinaryOperator,      // <>
    lt: BinaryOperator,      // <
    lte: BinaryOperator,     // <=
    gt: BinaryOperator,      // >
    gte: BinaryOperator,     // >=
    
    // Arithmetic Operators
    add: BinaryOperator,     // +
    sub: BinaryOperator,     // -
    mul: BinaryOperator,     // *
    div: BinaryOperator,     // /
    mod: BinaryOperator,     // %
    
    // Logical Operators
    logical_and: BinaryOperator,     // AND
    logical_or: BinaryOperator,      // OR
    logical_not: UnaryOperator,      // NOT
    
    // String Functions
    toUpper: UnaryOperator,
    toLower: UnaryOperator,
    trim: UnaryOperator,
    substring: SubstringOperator,
    
    // Mathematical Functions
    abs: UnaryOperator,
    round: UnaryOperator,
    ceil: UnaryOperator,
    floor: UnaryOperator,
    sqrt: UnaryOperator,
    
    // Aggregation Functions
    count: CountOperator,
    sum: UnaryOperator,
    avg: UnaryOperator,
    min: UnaryOperator,
    max: UnaryOperator,
};

pub fn deinitStatement(allocator: std.mem.Allocator, stmt: *Statement) void {
    switch (stmt.*) {
        .query => |*q| deinitQuery(allocator, q),
    }
}

fn deinitQuery(allocator: std.mem.Allocator, q: *Query) void {
    for (q.parts) |*part| {
        deinitPart(allocator, part);
    }
    allocator.free(q.parts);
    q.parts = &[_]Part{};
}

fn deinitPart(allocator: std.mem.Allocator, part: *Part) void {
    for (part.clauses) |*cl| deinitClause(allocator, cl);
    allocator.free(part.clauses);
    part.clauses = &[_]Clause{};
}

fn deinitClause(allocator: std.mem.Allocator, cl: *Clause) void {
    switch (cl.*) {
        .Match => |*m| {
            deinitPattern(allocator, &m.pattern);
            if (m.where) |*e| deinitExpr(allocator, e);
        },
        .OptionalMatch => |*m| {
            deinitPattern(allocator, &m.pattern);
            if (m.where) |*e| deinitExpr(allocator, e);
        },
        .With => |*w| {
            for (w.items) |*it| deinitExpr(allocator, &it.expr);
            allocator.free(w.items);
            if (w.order_by) |*ob| deinitOrderBy(allocator, ob);
        },
        .Return => |*r| {
            for (r.items) |*it| deinitExpr(allocator, &it.expr);
            allocator.free(r.items);
            if (r.order_by) |*ob| deinitOrderBy(allocator, ob);
        },
        .Create => |*c| {
            deinitPattern(allocator, &c.pattern);
        },
        .Merge => |*m| {
            deinitPattern(allocator, &m.pattern);
        },
        .Set => |*s| {
            for (s.items) |*it| switch (it.*) {
                .property => |*p| {
                    allocator.free(p.target.keys);
                    deinitExpr(allocator, &p.value);
                },
                .map_merge => |*mm| {
                    deinitMap(allocator, &mm.map);
                },
            };
            allocator.free(s.items);
        },
        .Delete => |*d| {
            for (d.expressions) |*e| deinitExpr(allocator, e);
            allocator.free(d.expressions);
        },
        .DetachDelete => |*d| {
            for (d.expressions) |*e| deinitExpr(allocator, e);
            allocator.free(d.expressions);
        },
        .Unwind => |*u| deinitExpr(allocator, &u.expr),
        .Remove => {},
        .OrderBy => |*ob| deinitOrderBy(allocator, ob),
        .Skip => {},
        .Limit => {},
        .Using => {},
    }
}

fn deinitOrderBy(allocator: std.mem.Allocator, ob: *OrderBy) void {
    for (ob.items) |*si| deinitExpr(allocator, &si.expr);
    allocator.free(ob.items);
}

fn deinitPattern(allocator: std.mem.Allocator, p: *Pattern) void {
    for (p.paths) |*path| {
        for (path.elements) |*el| switch (el.*) {
            .node => |*n| {
                if (n.properties) |*map| deinitMap(allocator, map);
                allocator.free(n.labels);
            },
            .relationship => |*r| {
                allocator.free(r.types);
                if (r.properties) |*map| deinitMap(allocator, map);
            },
        };
        allocator.free(path.elements);
    }
    allocator.free(p.paths);
}

fn deinitMap(allocator: std.mem.Allocator, map: *MapLiteral) void {
    for (map.entries) |*entry| deinitExpr(allocator, &entry.value);
    allocator.free(map.entries);
}

fn deinitExpr(allocator: std.mem.Allocator, e: *Expression) void {
    switch (e.*) {
        .property => |*ps| allocator.free(ps.keys),
        .map => |*map| deinitMap(allocator, map),
        .list => |*lst| allocator.free(lst.items),
        
        // Comparison Operators
        .eq, .ne, .lt, .lte, .gt, .gte => |*cmp| {
            deinitExpr(allocator, cmp.left);
            deinitExpr(allocator, cmp.right);
            allocator.destroy(cmp.left);
            allocator.destroy(cmp.right);
        },
        
        // Arithmetic Operators
        .add, .sub, .mul, .div, .mod => |*arith| {
            deinitExpr(allocator, arith.left);
            deinitExpr(allocator, arith.right);
            allocator.destroy(arith.left);
            allocator.destroy(arith.right);
        },
        
        // Logical Operators
        .logical_and, .logical_or => |*logical| {
            deinitExpr(allocator, logical.left);
            deinitExpr(allocator, logical.right);
            allocator.destroy(logical.left);
            allocator.destroy(logical.right);
        },
        .logical_not => |*not_expr| {
            deinitExpr(allocator, not_expr.expr);
            allocator.destroy(not_expr.expr);
        },
        
        // String Functions
        .toUpper, .toLower, .trim, .abs, .round, .ceil, .floor, .sqrt => |*func| {
            deinitExpr(allocator, func.expr);
            allocator.destroy(func.expr);
        },
        .substring => |*substr| {
            deinitExpr(allocator, substr.expr);
            deinitExpr(allocator, substr.start);
            deinitExpr(allocator, substr.length);
            allocator.destroy(substr.expr);
            allocator.destroy(substr.start);
            allocator.destroy(substr.length);
        },
        
        // Aggregation Functions
        .count => |*agg| {
            deinitExpr(allocator, agg.expr);
            allocator.destroy(agg.expr);
        },
        .sum, .avg, .min, .max => |*agg| {
            deinitExpr(allocator, agg.expr);
            allocator.destroy(agg.expr);
        },
        
        // Primary types (no cleanup needed)
        .variable, .string, .integer, .float, .boolean, .null => {},
    }
}
