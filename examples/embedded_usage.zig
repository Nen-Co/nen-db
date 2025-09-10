// Example: Using NenDB as an Embedded Database
// Similar to SQLite embedded usage patterns

const std = @import("std");
const nendb = @import("nendb");

pub fn main() !void {
    // Method 1: Quick start with defaults
    var db = try nendb.init();
    defer db.deinit();

    // Method 2: Specify data directory
    var db2 = try nendb.open("./my_app_data");
    defer db2.deinit();

    // Method 3: In-memory only (like SQLite :memory:)
    var memory_db = try nendb.open_memory();
    defer memory_db.deinit();

    // Method 4: Full configuration
    var configured_db = try nendb.create_graph(std.heap.page_allocator, .{
        .node_pool_size = 10000,
        .edge_pool_size = 50000,
        .data_dir = "./custom_data",
    });
    defer configured_db.deinit();

    // Use the database - all operations are in-process
    const stats = db.get_memory_stats();
    std.log.info("Nodes: {}, Edges: {}", .{ stats.nodes.used, stats.edges.used });

    // No server setup, no network calls, no external dependencies!
}

// Example: Embedding in a web application
pub const WebApp = struct {
    db: nendb.GraphDB,

    pub fn init() !WebApp {
        return WebApp{
            .db = try nendb.open("./webapp_data"),
        };
    }

    pub fn deinit(self: *WebApp) void {
        self.db.deinit();
    }

    pub fn handle_request(self: *WebApp, request: []const u8) ![]const u8 {
        _ = request; // Process request data as needed
        // Direct database calls - no network overhead!
        const stats = self.db.get_memory_stats();
        return std.fmt.allocPrint(std.heap.page_allocator, "Nodes: {}, Edges: {}", .{ stats.nodes.used, stats.edges.used });
    }
};
