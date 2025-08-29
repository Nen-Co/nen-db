// NenDB Client Library using Nen-Net
// Provides high-performance client APIs for database operations

const std = @import("std");
const nen_net = @import("nen-net");

pub const ClientConfig = struct {
    host: []const u8 = "localhost",
    port: u16 = 8080,
    timeout_ms: u32 = 5000,
    buffer_size: usize = 8192,
    enable_compression: bool = true,
    retry_attempts: u32 = 3,
    connection_pool_size: u32 = 10,
};

pub const Client = struct {
    config: ClientConfig,
    allocator: std.mem.Allocator,
    connections: std.ArrayList(ClientConnection),
    is_connected: bool = false,

    pub fn init(allocator: std.mem.Allocator, config: ClientConfig) !Client {
        return Client{
            .config = config,
            .allocator = allocator,
            .connections = std.ArrayList(ClientConnection).init(allocator),
        };
    }

    pub fn deinit(self: *Client) void {
        self.disconnect();
        self.connections.deinit();
    }

    pub fn connect(self: *Client) !void {
        if (self.is_connected) return;

        std.debug.print("🔌 Connecting to NenDB server at {s}:{d}...\n", .{ self.config.host, self.config.port });

        // Initialize connection pool
        for (0..self.config.connection_pool_size) |_| {
            const conn = try ClientConnection.init(self.allocator, self.config);
            try self.connections.append(conn);
        }

        // Test connection with first connection
        const test_conn = &self.connections.items[0];
        try test_conn.connect();
        
        // Send test ping
        const response = try self.sendRequest(test_conn, "PING");
        if (!response.success) {
            return error.ConnectionFailed;
        }

        self.is_connected = true;
        std.debug.print("✅ Connected to NenDB server\n", .{});
    }

    pub fn disconnect(self: *Client) void {
        if (!self.is_connected) return;

        std.debug.print("🔌 Disconnecting from NenDB server...\n", .{});
        
        for (self.connections.items) |*conn| {
            conn.close();
        }
        
        self.is_connected = false;
        std.debug.print("✅ Disconnected from NenDB server\n", .{});
    }

    fn getConnection(self: *Client) !*ClientConnection {
        if (self.connections.items.len == 0) return error.NoConnectionsAvailable;
        
        // Simple round-robin connection selection
        const index = @mod(self.connections.items.len, self.connections.items.len);
        return &self.connections.items[index];
    }

    fn sendRequest(self: *Client, conn: *ClientConnection, request: []const u8) !Response {
        _ = self; // Client instance not used in this function
        try conn.write(request);
        const data = try conn.read();
        return parseResponse(data);
    }

    // Graph Database Operations
    pub fn insertNode(self: *Client, id: []const u8, labels: []const []const u8, properties: std.StringHashMap([]const u8)) !Response {
        const conn = try self.getConnection();
        
        // Format: GRAPH:INSERT_NODE:id:labels:properties
        var request_buf: [1024]u8 = undefined;
        var stream = std.io.fixedBufferStream(&request_buf);
        var writer = stream.writer();
        
        try writer.print("GRAPH:INSERT_NODE:{s}:", .{id});
        
        // Add labels
        for (labels, 0..) |label, i| {
            if (i > 0) try writer.writeAll(",");
            try writer.print("{s}", .{label});
        }
        try writer.writeAll(":");
        
        // Add properties count for now (will implement full properties later)
        const property_count = properties.count();
        try writer.print("properties:{d}", .{property_count});
        
        const request = stream.getWritten();
        return self.sendRequest(conn, request);
    }

    pub fn insertEdge(self: *Client, from_id: []const u8, to_id: []const u8, relationship_type: []const u8, properties: std.StringHashMap([]const u8)) !Response {
        const conn = try self.getConnection();
        
        // Format: GRAPH:INSERT_EDGE:from_id:to_id:type:properties
        var request_buf: [1024]u8 = undefined;
        var stream = std.io.fixedBufferStream(&request_buf);
        var writer = stream.writer();
        
        try writer.print("GRAPH:INSERT_EDGE:{s}:{s}:{s}:properties:{d}", .{ from_id, to_id, relationship_type, properties.count() });
        
        const request = stream.getWritten();
        return self.sendRequest(conn, request);
    }

    pub fn query(self: *Client, cypher: []const u8, parameters: std.StringHashMap([]const u8)) !Response {
        const conn = try self.getConnection();
        
        // Format: GRAPH:QUERY:cypher:parameters
        var request_buf: [2048]u8 = undefined;
        var stream = std.io.fixedBufferStream(&request_buf);
        var writer = stream.writer();
        
        try writer.print("GRAPH:QUERY:{s}:params:{d}", .{ cypher, parameters.count() });
        
        const request = stream.getWritten();
        return self.sendRequest(conn, request);
    }

    // Document Database Operations
    pub fn insertDocument(self: *Client, collection: []const u8, document: []const u8) !Response {
        const conn = try self.getConnection();
        
        // Format: DOC:INSERT:collection:document
        var request_buf: [4096]u8 = undefined;
        var stream = std.io.fixedBufferStream(&request_buf);
        var writer = stream.writer();
        
        try writer.print("DOC:INSERT:{s}:{s}", .{ collection, document });
        
        const request = stream.getWritten();
        return self.sendRequest(conn, request);
    }

    pub fn findDocument(self: *Client, collection: []const u8, query_string: []const u8) !Response {
        const conn = try self.getConnection();
        
        // Format: DOC:FIND:collection:query
        var request_buf: [4096]u8 = undefined;
        var stream = std.io.fixedBufferStream(&request_buf);
        var writer = stream.writer();
        
        try writer.print("DOC:FIND:{s}:{s}", .{ collection, query_string });
        
        const request = stream.getWritten();
        return self.sendRequest(conn, request);
    }

    pub fn updateDocument(self: *Client, collection: []const u8, id: []const u8, updates: []const u8) !Response {
        const conn = try self.getConnection();
        
        // Format: DOC:UPDATE:collection:id:updates
        var request_buf: [4096]u8 = undefined;
        var stream = std.io.fixedBufferStream(&request_buf);
        var writer = stream.writer();
        
        try writer.print("DOC:UPDATE:{s}:{s}:{s}", .{ collection, id, updates });
        
        const request = stream.getWritten();
        return self.sendRequest(conn, request);
    }

    pub fn deleteDocument(self: *Client, collection: []const u8, id: []const u8) !Response {
        const conn = try self.getConnection();
        
        // Format: DOC:DELETE:collection:id
        var request_buf: [1024]u8 = undefined;
        var stream = std.io.fixedBufferStream(&request_buf);
        var writer = stream.writer();
        
        try writer.print("DOC:DELETE:{s}:{s}", .{ collection, id });
        
        const request = stream.getWritten();
        return self.sendRequest(conn, request);
    }

    // Key-Value Operations
    pub fn set(self: *Client, key: []const u8, value: []const u8, ttl: ?u64) !Response {
        const conn = try self.getConnection();
        
        // Format: KV:SET:key:value:ttl
        var request_buf: [4096]u8 = undefined;
        var stream = std.io.fixedBufferStream(&request_buf);
        var writer = stream.writer();
        
        if (ttl) |ttl_value| {
            try writer.print("KV:SET:{s}:{s}:{d}", .{ key, value, ttl_value });
        } else {
            try writer.print("KV:SET:{s}:{s}:0", .{ key, value });
        }
        
        const request = stream.getWritten();
        return self.sendRequest(conn, request);
    }

    pub fn get(self: *Client, key: []const u8) !Response {
        const conn = try self.getConnection();
        
        // Format: KV:GET:key
        var request_buf: [1024]u8 = undefined;
        var stream = std.io.fixedBufferStream(&request_buf);
        var writer = stream.writer();
        
        try writer.print("KV:GET:{s}", .{key});
        
        const request = stream.getWritten();
        return self.sendRequest(conn, request);
    }

    pub fn delete(self: *Client, key: []const u8) !Response {
        const conn = try self.getConnection();
        
        // Format: KV:DELETE:key
        var request_buf: [1024]u8 = undefined;
        var stream = std.io.fixedBufferStream(&request_buf);
        var writer = stream.writer();
        
        try writer.print("KV:DELETE:{s}", .{key});
        
        const request = stream.getWritten();
        return self.sendRequest(conn, request);
    }

    // Utility operations
    pub fn ping(self: *Client) !Response {
        const conn = try self.getConnection();
        return self.sendRequest(conn, "PING");
    }

    pub fn status(self: *Client) !Response {
        const conn = try self.getConnection();
        return self.sendRequest(conn, "STATUS");
    }
};

pub const ClientConnection = struct {
    config: ClientConfig,
    allocator: std.mem.Allocator,
    socket: ?std.net.Stream = null,
    buffer: []u8,
    is_connected: bool = false,

    pub fn init(allocator: std.mem.Allocator, config: ClientConfig) !ClientConnection {
        const buffer = try allocator.alloc(u8, config.buffer_size);
        return ClientConnection{
            .config = config,
            .allocator = allocator,
            .buffer = buffer,
        };
    }

    pub fn deinit(self: *ClientConnection) void {
        self.close();
        self.allocator.free(self.buffer);
    }

    pub fn connect(self: *ClientConnection) !void {
        if (self.is_connected) return;

        const address = try std.net.Address.parseIp(self.config.host, self.config.port);
        self.socket = try std.net.tcpConnectToAddress(address);
        self.is_connected = true;
    }

    pub fn close(self: *ClientConnection) void {
        if (self.socket) |*socket| {
            socket.close();
        }
        self.is_connected = false;
    }

    pub fn write(self: *ClientConnection, data: []const u8) !void {
        if (self.socket) |*socket| {
            try socket.writeAll(data);
        } else {
            return error.NotConnected;
        }
    }

    pub fn read(self: *ClientConnection) ![]const u8 {
        if (self.socket) |*socket| {
            const n = try socket.read(self.buffer);
            return self.buffer[0..n];
        } else {
            return error.NotConnected;
        }
    }
};

pub const Response = struct {
    success: bool,
    data: ?[]const u8 = null,
    error_message: ?[]const u8 = null,
    metadata: ?std.StringHashMap([]const u8) = null,
};

fn parseResponse(data: []const u8) Response {
    // Simple response parsing - in production, use proper JSON parsing
    const response = std.mem.trim(u8, data, " \r\n");
    
    if (std.mem.startsWith(u8, response, "{\"success\":true")) {
        return Response{ .success = true, .data = "Success" };
    } else if (std.mem.startsWith(u8, response, "{\"success\":false")) {
        return Response{ .success = false, .error_message = "Request failed" };
    } else {
        return Response{ .success = true, .data = response };
    }
}

// Convenience function to create and connect a client
pub fn createClient(allocator: std.mem.Allocator, host: []const u8, port: u16) !Client {
    const config = ClientConfig{ .host = host, .port = port };
    var client = try Client.init(allocator, config);
    try client.connect();
    return client;
}
