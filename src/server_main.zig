// NenDB Server Main - HTTP Server with Graph Algorithm Endpoints
// Follows Nen way: inline functions, static memory, efficient allocation
// Uses nen-net for high-performance networking

const std = @import("std");
const server = @import("api/server.zig");
const algorithms = @import("algorithms/algorithms.zig");

// Main server function
pub fn main() !void {
    std.debug.print("🚀 Starting NenDB Enhanced Server on port 8080...\n", .{});
    std.debug.print("📊 Available endpoints:\n", .{});
    std.debug.print("   GET  /health\n", .{});
    std.debug.print("   GET  /graph/stats\n", .{});
    std.debug.print("   POST /graph/algorithms/bfs\n", .{});
    std.debug.print("   POST /graph/algorithms/dijkstra\n", .{});
    std.debug.print("   POST /graph/algorithms/pagerank\n", .{});
    
    // Use the enhanced server infrastructure
    try server.startDefaultServer(8080);
}
