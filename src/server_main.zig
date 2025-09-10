// NenDB Server Main - HTTP Server with Graph Algorithm Endpoints
// Follows Nen way: inline functions, static memory, efficient allocation
// Uses nen-net for high-performance networking

const std = @import("std");
const nen_net = @import("nen-net");
const algorithms = @import("algorithms/algorithms.zig");
const constants = @import("constants.zig");

// Main server function
pub fn main() !void {
    std.debug.print("🚀 Starting NenDB Server using nen-net on port 8080...\n", .{});
    std.debug.print("📊 Available endpoints:\n", .{});
    std.debug.print("   GET  /health\n", .{});
    std.debug.print("   GET  /graph/stats\n", .{});
    std.debug.print("   POST /graph/algorithms/bfs\n", .{});
    std.debug.print("   POST /graph/algorithms/dijkstra\n", .{});
    std.debug.print("   POST /graph/algorithms/pagerank\n", .{});

    // Create HTTP server using enhanced nen-net
    var server = try nen_net.createHttpServer(8080);

    // Add graph algorithm endpoints
    try server.addRoute(.POST, "/graph/algorithms/bfs", handleBFS);
    try server.addRoute(.POST, "/graph/algorithms/dijkstra", handleDijkstra);
    try server.addRoute(.POST, "/graph/algorithms/pagerank", handlePageRank);

    // Add utility endpoints
    try server.addRoute(.GET, "/graph/stats", handleGraphStats);
    try server.addRoute(.GET, "/health", handleHealth);
    try server.addRoute(.GET, "/", handleRoot);

    std.debug.print("✅ Server configured with {d} routes\n", .{6});
    std.debug.print("🌐 Starting nen-net HTTP server...\n", .{});

    // Start the server
    try server.start();
}

// Route handlers following Nen way
fn handleBFS(request: *nen_net.http.HttpRequest, response: *nen_net.http.HttpResponse) void {
    _ = request;
    response.status_code = .OK;
    response.setBody("{\"algorithm\": \"bfs\", \"status\": \"queued\", \"message\": \"BFS algorithm queued for execution\"}");
}

fn handleDijkstra(request: *nen_net.http.HttpRequest, response: *nen_net.http.HttpResponse) void {
    _ = request;
    response.status_code = .OK;
    response.setBody("{\"algorithm\": \"dijkstra\", \"status\": \"queued\", \"message\": \"Dijkstra algorithm queued for execution\"}");
}

fn handlePageRank(request: *nen_net.http.HttpRequest, response: *nen_net.http.HttpResponse) void {
    _ = request;
    response.status_code = .OK;
    response.setBody("{\"algorithm\": \"pagerank\", \"status\": \"queued\", \"message\": \"PageRank algorithm queued for execution\"}");
}

fn handleGraphStats(request: *nen_net.http.HttpRequest, response: *nen_net.http.HttpResponse) void {
    _ = request;
    response.status_code = .OK;
    response.setBody("{\"nodes\": 0, \"edges\": 0, \"algorithms\": [\"bfs\", \"dijkstra\", \"pagerank\"], \"status\": \"operational\"}");
}

fn handleHealth(request: *nen_net.http.HttpRequest, response: *nen_net.http.HttpResponse) void {
    _ = request;
    response.status_code = .OK;
    const body = std.fmt.allocPrint(std.heap.page_allocator, "{{\"status\": \"healthy\", \"service\": \"nendb\", \"version\": \"{s}\"}}", .{constants.VERSION_STRING}) catch "{\"status\": \"healthy\", \"service\": \"nendb\", \"version\": \"unknown\"}";
    response.setBody(body);
}

fn handleRoot(request: *nen_net.http.HttpRequest, response: *nen_net.http.HttpResponse) void {
    _ = request;
    response.status_code = .OK;
    const body = std.fmt.allocPrint(std.heap.page_allocator, "{{\"service\": \"NenDB\", \"version\": \"{s}\", \"endpoints\": {{\"health\": \"/health\", \"graph_stats\": \"/graph/stats\", \"algorithms\": \"/graph/algorithms/{{bfs|dijkstra|pagerank}}\"}}}}", .{constants.VERSION_STRING}) catch "{\"service\": \"NenDB\", \"version\": \"unknown\", \"endpoints\": {\"health\": \"/health\", \"graph_stats\": \"/graph/stats\", \"algorithms\": \"/graph/algorithms/{bfs|dijkstra|pagerank}\"}}";
    response.setBody(body);
}
