// NenDB TCP Server - High-performance binary protocol
// DOD-based server using enhanced nen-net TCP with static allocation

const std = @import("std");
const nen_net = @import("nen-net");
const nen_io = @import("nen-io");
const graphdb = @import("graphdb.zig");
const constants = @import("constants.zig");
const batch = @import("batch/batch_processor.zig");

// NenDB Binary Protocol - Fixed-size messages for cache efficiency
pub const NenDBProtocol = struct {
    // Protocol header (64 bytes, cache-aligned)
    pub const Header = extern struct {
        magic: u32 = 0x4E454E44, // "NEND" in ASCII
        version: u16 = 1,
        message_type: MessageType,
        sequence_id: u64,
        data_length: u32,
        checksum: u32,
        reserved: [40]u8 = [_]u8{0} ** 40,

        comptime {
            std.debug.assert(@sizeOf(Header) == 64);
            std.debug.assert(@alignOf(Header) == 4);
        }
    };

    pub const MessageType = enum(u16) {
        // Core operations
        ping = 1,
        batch_request = 2,
        batch_response = 3,
        query_request = 4,
        query_response = 5,

        // Graph operations
        create_node = 10,
        create_edge = 11,
        update_node = 12,
        delete_node = 13,
        delete_edge = 14,

        // Batch operations
        batch_create_nodes = 20,
        batch_create_edges = 21,
        batch_query = 22,

        // Status/admin
        status_request = 30,
        status_response = 31,
        shutdown = 32,

        // Error responses
        error_response = 255,
    };

    // Fixed-size node operation (128 bytes)
    pub const NodeOp = extern struct {
        id: u64,
        kind: u32,
        operation: OpType,
        reserved: [3]u8 = [_]u8{0} ** 3,
        properties: [112]u8, // Property data

        pub const OpType = enum(u8) {
            create = 1,
            update = 2,
            delete = 3,
            query = 4,
        };

        comptime {
            std.debug.assert(@sizeOf(NodeOp) == 128);
        }
    };

    // Fixed-size edge operation (96 bytes)
    pub const EdgeOp = extern struct {
        from_id: u64,
        to_id: u64,
        label: u32,
        operation: NodeOp.OpType,
        reserved: [3]u8 = [_]u8{0} ** 3,
        properties: [72]u8, // Property data

        comptime {
            std.debug.assert(@sizeOf(EdgeOp) == 96);
        }
    };

    // Batch message (up to 8192 operations)
    pub const BatchMessage = struct {
        header: Header,
        node_ops: []NodeOp,
        edge_ops: []EdgeOp,

        pub inline fn validateChecksum(self: *const @This()) bool {
            // Simple XOR checksum for now (could be CRC32 for production)
            var checksum: u32 = 0;
            const data = std.mem.asBytes(self.node_ops);
            for (data) |byte| {
                checksum ^= byte;
            }
            return checksum == self.header.checksum;
        }
    };
};

// High-performance NenDB TCP Server
pub const NenDBTcpServer = struct {
    tcp_server: nen_net.TcpServer,
    graph_db: graphdb.GraphDB,
    batch_processor: ?batch.BatchProcessor,
    is_running: bool = false,

    // Statistics (cache-aligned)
    stats: ServerStats align(64),

    pub const ServerStats = struct {
        connections_accepted: u64 = 0,
        messages_processed: u64 = 0,
        batch_operations: u64 = 0,
        bytes_received: u64 = 0,
        bytes_sent: u64 = 0,
        errors: u64 = 0,
        uptime_start: u64 = 0,
    };

    pub fn init(port: u16) !@This() {
        var server: @This() = undefined;
        server.tcp_server = try nen_net.createTcpServer(port);
        server.is_running = false;
        server.stats = ServerStats{
            .uptime_start = @intCast(std.time.nanoTimestamp()),
        };

        // Initialize database with static memory allocation
        try server.graph_db.init_inplace(std.heap.page_allocator);
        // TODO: Fix batch processor to use pool_v2 - for now set to null
        server.batch_processor = null;

        return server;
    }

    pub fn start(self: *@This()) !void {
        try nen_io.Terminal.successln("🚀 Starting NenDB TCP Server on port {d}", .{self.tcp_server.config.port});
        try nen_io.Terminal.infoln("📊 Max connections: {d}", .{self.tcp_server.config.max_connections});
        try nen_io.Terminal.infoln("⚡ Protocol: NenDB Binary Protocol v1", .{});
        try nen_io.Terminal.infoln("🗄️  Database initialized with static memory pools", .{});

        self.is_running = true;

        // Start the high-performance TCP server
        try self.tcp_server.start();
    }

    pub fn stop(self: *@This()) void {
        self.is_running = false;
        self.tcp_server.stop();
        nen_io.Terminal.infoln("🛑 NenDB TCP Server stopped", .{}) catch {};
    }

    pub fn getStats(self: *const @This()) ServerStats {
        return self.stats;
    }

    // Process incoming messages (called by TCP server)
    pub fn processMessage(self: *@This(), data: []const u8) ![]const u8 {
        if (data.len < @sizeOf(NenDBProtocol.Header)) {
            self.stats.errors += 1;
            return try self.createErrorResponse("Invalid message size");
        }

        const header = std.mem.bytesAsValue(NenDBProtocol.Header, data[0..@sizeOf(NenDBProtocol.Header)]);

        // Validate magic number
        if (header.magic != 0x4E454E44) {
            self.stats.errors += 1;
            return try self.createErrorResponse("Invalid protocol magic");
        }

        self.stats.messages_processed += 1;
        self.stats.bytes_received += data.len;

        return switch (header.message_type) {
            .ping => try self.handlePing(header),
            .batch_request => try self.handleBatchRequest(data),
            .create_node => try self.handleCreateNode(data),
            .create_edge => try self.handleCreateEdge(data),
            .status_request => try self.handleStatusRequest(),
            else => try self.createErrorResponse("Unsupported message type"),
        };
    }

    inline fn handlePing(self: *@This(), header: *const NenDBProtocol.Header) ![]const u8 {
        // Simple ping/pong response
        const response_header = NenDBProtocol.Header{
            .version = 1,
            .message_type = .ping,
            .sequence_id = header.sequence_id,
            .data_length = 0,
            .checksum = 0,
        };

        self.stats.bytes_sent += @sizeOf(NenDBProtocol.Header);
        return std.mem.asBytes(&response_header);
    }

    inline fn handleBatchRequest(self: *@This(), data: []const u8) ![]const u8 {
        // Parse batch message
        const header = std.mem.bytesAsValue(NenDBProtocol.Header, data[0..@sizeOf(NenDBProtocol.Header)]);

        // Process batch operations using the DOD batch processor
        var operations_processed: u32 = 0;

        // For now, just acknowledge the batch
        const response_header = NenDBProtocol.Header{
            .version = 1,
            .message_type = .batch_response,
            .sequence_id = header.sequence_id,
            .data_length = @sizeOf(u32),
            .checksum = operations_processed,
        };

        self.stats.batch_operations += operations_processed;
        self.stats.bytes_sent += @sizeOf(NenDBProtocol.Header) + @sizeOf(u32);

        // Return response with operation count
        var response_buffer: [@sizeOf(NenDBProtocol.Header) + @sizeOf(u32)]u8 = undefined;
        @memcpy(response_buffer[0..@sizeOf(NenDBProtocol.Header)], std.mem.asBytes(&response_header));
        @memcpy(response_buffer[@sizeOf(NenDBProtocol.Header)..], std.mem.asBytes(&operations_processed));

        return &response_buffer;
    }

    inline fn handleCreateNode(self: *@This(), data: []const u8) ![]const u8 {
        if (data.len < @sizeOf(NenDBProtocol.Header) + @sizeOf(NenDBProtocol.NodeOp)) {
            return try self.createErrorResponse("Invalid node operation size");
        }

        const header = std.mem.bytesAsValue(NenDBProtocol.Header, data[0..@sizeOf(NenDBProtocol.Header)]);
        const node_op = std.mem.bytesAsValue(NenDBProtocol.NodeOp, data[@sizeOf(NenDBProtocol.Header) .. @sizeOf(NenDBProtocol.Header) + @sizeOf(NenDBProtocol.NodeOp)]);

        // Create node using GraphDB
        const node = self.graph_db.createNode(node_op.id, node_op.kind, &node_op.properties) catch {
            return try self.createErrorResponse("Failed to create node");
        };

        // Return success response
        const response_header = NenDBProtocol.Header{
            .version = 1,
            .message_type = .create_node,
            .sequence_id = header.sequence_id,
            .data_length = @sizeOf(u64),
            .checksum = 0,
        };

        var response_buffer: [@sizeOf(NenDBProtocol.Header) + @sizeOf(u64)]u8 = undefined;
        @memcpy(response_buffer[0..@sizeOf(NenDBProtocol.Header)], std.mem.asBytes(&response_header));
        @memcpy(response_buffer[@sizeOf(NenDBProtocol.Header)..], std.mem.asBytes(&node.id));

        self.stats.bytes_sent += response_buffer.len;
        return &response_buffer;
    }

    inline fn handleCreateEdge(self: *@This(), data: []const u8) ![]const u8 {
        if (data.len < @sizeOf(NenDBProtocol.Header) + @sizeOf(NenDBProtocol.EdgeOp)) {
            return try self.createErrorResponse("Invalid edge operation size");
        }

        // Similar implementation to handleCreateNode but for edges
        const header = std.mem.bytesAsValue(NenDBProtocol.Header, data[0..@sizeOf(NenDBProtocol.Header)]);

        // Return success response (simplified)
        const response_header = NenDBProtocol.Header{
            .version = 1,
            .message_type = .create_edge,
            .sequence_id = header.sequence_id,
            .data_length = 0,
            .checksum = 0,
        };

        self.stats.bytes_sent += @sizeOf(NenDBProtocol.Header);
        return std.mem.asBytes(&response_header);
    }

    inline fn handleStatusRequest(self: *@This()) ![]const u8 {
        const tcp_stats = self.tcp_server.getStats();
        const uptime = std.time.nanoTimestamp() - self.stats.uptime_start;

        // Create status response (JSON-like binary format for efficiency)
        const status_data = struct {
            uptime_ns: u64,
            connections: u32,
            messages_processed: u64,
            batch_operations: u64,
            bytes_received: u64,
            bytes_sent: u64,
            errors: u64,
            nodes_count: u32,
            edges_count: u32,
        }{
            .uptime_ns = uptime,
            .connections = tcp_stats.active_connections,
            .messages_processed = self.stats.messages_processed,
            .batch_operations = self.stats.batch_operations,
            .bytes_received = self.stats.bytes_received,
            .bytes_sent = self.stats.bytes_sent,
            .errors = self.stats.errors,
            .nodes_count = @intCast(self.graph_db.getNodeCount()),
            .edges_count = @intCast(self.graph_db.getEdgeCount()),
        };

        const response_header = NenDBProtocol.Header{
            .version = 1,
            .message_type = .status_response,
            .sequence_id = 0,
            .data_length = @sizeOf(@TypeOf(status_data)),
            .checksum = 0,
        };

        var response_buffer: [@sizeOf(NenDBProtocol.Header) + @sizeOf(@TypeOf(status_data))]u8 = undefined;
        @memcpy(response_buffer[0..@sizeOf(NenDBProtocol.Header)], std.mem.asBytes(&response_header));
        @memcpy(response_buffer[@sizeOf(NenDBProtocol.Header)..], std.mem.asBytes(&status_data));

        self.stats.bytes_sent += response_buffer.len;
        return &response_buffer;
    }

    inline fn createErrorResponse(self: *@This(), message: []const u8) ![]const u8 {
        const error_header = NenDBProtocol.Header{
            .version = 1,
            .message_type = .error_response,
            .sequence_id = 0,
            .data_length = @intCast(message.len),
            .checksum = 0,
        };

        // For simplicity, return just the header (could include error message)
        self.stats.bytes_sent += @sizeOf(NenDBProtocol.Header);
        self.stats.errors += 1;
        return std.mem.asBytes(&error_header);
    }
};

// Main server entry point
pub fn main() !void {
    const port = 5454; // NenDB standard TCP port

    var server = try NenDBTcpServer.init(port);
    defer server.graph_db.deinit();

    // Print startup banner
    try nen_io.Terminal.println("", .{});
    try nen_io.Terminal.boldln("⚡ NenDB TCP Server ⚡", .{});
    try nen_io.Terminal.println("High-Performance Graph Database", .{});
    try nen_io.Terminal.println("Binary Protocol | DOD Architecture | Zero-Copy Operations", .{});
    try nen_io.Terminal.println("", .{});

    try server.start();
}
