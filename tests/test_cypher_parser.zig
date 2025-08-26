const std = @import("std");
const query = @import("../src/query/query.zig");

// Basic smoke tests ensuring our minimal Cypher-like parser accepts a subset of openCypher-like forms.
// This is NOT full openCypher compliance; it guards existing behavior while we expand.
// Reference: openCypher v9 (subset targeted: MATCH node/edge, RETURN list, simple WHERE equality, CREATE node with props)

fn expectParse(q: []const u8) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();
    _ = try query.parse_query(q, alloc);
}

test "cypher subset: MATCH node RETURN" { try expectParse("MATCH (n) RETURN n"); }

test "cypher subset: MATCH node WHERE equality RETURN" { try expectParse("MATCH (n) WHERE n.kind = 1 RETURN n"); }

test "cypher subset: MATCH edge RETURN" { try expectParse("MATCH (a)-[e]->(b) RETURN a,b"); }

test "cypher subset: MATCH edge USING BFS RETURN" { try expectParse("MATCH (a)-[e]->(b) USING BFS RETURN a"); }

test "cypher subset: CREATE node with props" { try expectParse("CREATE (u {id: \"alice\", kind: 0})"); }

test "cypher subset: SET property" { try expectParse("SET n.kind = 2"); }

test "cypher subset: DELETE node" { try expectParse("DELETE (n)"); }
