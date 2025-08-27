const std = @import("std");
const query = @import("query");

fn expectParseNew(q: []const u8) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();
    var stmt = try query.parse_cypher(q, alloc);
    query.cypher_ast.deinitStatement(alloc, &stmt);
}

test "new cypher: OPTIONAL MATCH + WITH + RETURN" {
    try expectParseNew("OPTIONAL MATCH (n:User) WITH n RETURN n");
}

test "new cypher: RETURN with ORDER BY, SKIP, LIMIT" {
    try expectParseNew("MATCH (n) RETURN n ORDER BY n.kind DESC SKIP 1 LIMIT 2");
}

test "new cypher: UNWIND + SET + DELETE" {
    try expectParseNew("UNWIND [1,2,3] AS x MATCH (n) SET n.kind = 1, n.score = 3.14 DELETE n");
}
