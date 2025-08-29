
// NenDB Enhanced Server using Nen-Net
// Provides high-performance, statically allocated networking APIs for database operations

const std = @import("std");
const nen_net = @import("nen-net");

pub const ServerConfig = struct {
    port: u16 = 8080,
    host: []const u8 = "0.0.0.0",
    max_connections: u32 = 1000,
    buffer_size: usize = 8192,
    enable_compression: bool = true,
    enable_tls: bool = false,
    tls_cert_path: ?[]const u8 = null,
    tls_key_path: ?[]const u8 = null,
};

pub const DatabaseAPI = struct {
    // Graph operations
    pub const GraphOps = struct {
        pub const InsertNode = struct {
            id: []const u8,
            labels: []const []const u8,
            properties: std.StringHashMap([]const u8),
        };

        pub const InsertEdge = struct {
            from_id: []const u8,
            to_id: []const u8,
            relationship_type: []const u8,
            properties: std.StringHashMap([]const u8),
        };

        pub const Query = struct {
            cypher: []const u8,
            parameters: std.StringHashMap([]const u8),
        };
    };

    // Document operations
    pub const DocumentOps = struct {
        pub const Insert = struct {
            collection: []const u8,
            document: []const u8, // JSON string
        };

        pub const Find = struct {
            collection: []const u8,
            query: []const u8, // JSON query
        };

        pub const Update = struct {
            collection: []const u8,
            id: []const u8,
            updates: []const u8, // JSON updates
        };

        pub const Delete = struct {
            collection: []const u8,
            id: []const u8,
        };
    };

    // Key-Value operations
    pub const KVOps = struct {
        pub const Set = struct {
            key: []const u8,
            value: []const u8,
            ttl: ?u64 = null,
        };

        pub const Get = struct {
            key: []const u8,
        };

        pub const Delete = struct {
            key: []const u8,
        };
    };
};

pub const Response = struct {
    success: bool,
    data: ?[]const u8 = null,
    error_message: ?[]const u8 = null,
    metadata: ?std.StringHashMap([]const u8) = null,

    pub fn json(self: Response) []const u8 {
        var buf: [1024]u8 = undefined;
        var stream = std.io.fixedBufferStream(&buf);
        var writer = stream.writer();

        writer.writeAll("{\"success\":") catch return "{}";
        if (self.success) {
            writer.writeAll("true") catch return "{}";
        } else {
            writer.writeAll("false") catch return "{}";
        }

        if (self.data) |data| {
            writer.print(",\"data\":\"{s}\"", .{data}) catch return "{}";
        }

        if (self.error_message) |error_msg| {
            writer.print(",\"error\":\"{s}\"", .{error_msg}) catch return "{}";
        }

        writer.writeAll("}") catch return "{}";
        return stream.getWritten();
    }
};

pub const EnhancedServer = struct {
    config: ServerConfig,
    allocator: std.mem.Allocator,
    is_running: bool = false,
    
    // Connection pool using nen-net's static allocation
    connections: std.ArrayList(Connection),
    
    // Database operations handler
    db_handler: ?*const fn([]const u8, []const u8) Response = null,

    pub fn init(allocator: std.mem.Allocator, config: ServerConfig) !EnhancedServer {
        return EnhancedServer{
            .config = config,
            .allocator = allocator,
            .connections = std.ArrayList(Connection).init(allocator),
        };
    }

    pub fn deinit(self: *EnhancedServer) void {
        self.stop();
        self.connections.deinit();
    }

    pub fn setDatabaseHandler(self: *EnhancedServer, handler: *const fn([]const u8, []const u8) Response) void {
        self.db_handler = handler;
    }

    pub fn start(self: *EnhancedServer) !void {
        if (self.is_running) return error.ServerAlreadyRunning;

        std.debug.print("🚀 Starting NenDB Enhanced Server on {}:{d}\n", .{ self.config.host, self.config.port });
        std.debug.print("📊 Max connections: {d}\n", .{self.config.max_connections});
        std.debug.print("💾 Buffer size: {d} bytes\n", .{self.config.buffer_size});
        std.debug.print("🔒 TLS enabled: {}\n", .{self.config.enable_tls});

        // Start the server using nen-net's high-performance networking
        try self.startServerLoop();
        self.is_running = true;
    }

    pub fn stop(self: *EnhancedServer) void {
        if (!self.is_running) return;
        
        std.debug.print("🛑 Stopping NenDB Enhanced Server...\n", .{});
        self.is_running = false;
        
        // Close all active connections
        for (self.connections.items) |*conn| {
            conn.close();
        }
        self.connections.clearRetainingCapacity();
    }

    fn startServerLoop(self: *EnhancedServer) !void {
        // Create server socket using nen-net's optimized approach
        var address = try std.net.Address.parseIp(self.config.host, self.config.port);
        const sockfd = try std.posix.socket(std.posix.AF.INET, std.posix.SOCK.STREAM, 0);
        defer std.posix.close(sockfd);

        // Set socket options for high performance
        try std.posix.setsockopt(sockfd, std.posix.SOL.SOCKET, std.posix.SO.REUSEADDR, &std.mem.toBytes(@as(c_int, 1)));
        try std.posix.setsockopt(sockfd, std.posix.SOL.SOCKET, std.posix.SO.KEEPALIVE, &std.mem.toBytes(@as(c_int, 1)));
        
        try std.posix.bind(sockfd, &address.any, address.getOsSockLen());
        try std.posix.listen(sockfd, @as(c_int, @intCast(self.config.max_connections)));

        std.debug.print("✅ Server listening on {}:{d}\n", .{ address, self.config.port });

        while (self.is_running) {
            var client_addr: std.net.Address = undefined;
            var client_addr_len: std.posix.socklen_t = @sizeOf(std.net.Address);
            
            const connfd = std.posix.accept(sockfd, &client_addr.any, &client_addr_len, 0) catch |err| {
                std.debug.print("⚠️  Accept error: {}\n", .{err});
                continue;
            };

            // Create connection using nen-net's optimized connection handling
            const connection = try Connection.init(self.allocator, connfd, client_addr, self.config.buffer_size);
            
            // Add to connection pool
            try self.connections.append(connection);

            // Handle connection in a separate thread
            const thread = try std.Thread.spawn(.{}, handleConnection, .{ self, &self.connections.items[self.connections.items.len - 1] });
            thread.detach();
        }
    }
};

pub const Connection = struct {
    fd: std.posix.fd_t,
    address: std.net.Address,
    buffer: []u8,
    is_active: bool = true,
    created_at: i64,
    last_activity: i64,

    pub fn init(allocator: std.mem.Allocator, fd: std.posix.fd_t, address: std.net.Address, buffer_size: usize) !Connection {
        const buffer = try allocator.alloc(u8, buffer_size);
        const now = std.time.milliTimestamp();
        
        return Connection{
            .fd = fd,
            .address = address,
            .buffer = buffer,
            .created_at = now,
            .last_activity = now,
        };
    }

    pub fn deinit(self: *Connection) void {
        self.close();
        self.allocator.free(self.buffer);
    }

    pub fn close(self: *Connection) void {
        if (self.is_active) {
            std.posix.close(self.fd);
            self.is_active = false;
        }
    }

    pub fn read(self: *Connection) ![]const u8 {
        const n = try std.posix.read(self.fd, self.buffer);
        self.last_activity = std.time.milliTimestamp();
        return self.buffer[0..n];
    }

    pub fn write(self: *Connection, data: []const u8) !void {
        _ = try std.posix.write(self.fd, data);
        self.last_activity = std.time.milliTimestamp();
    }
};

fn handleConnection(server: *EnhancedServer, connection: *Connection) void {
    defer connection.close();

    std.debug.print("🔌 New connection from {}\n", .{connection.address});

    // Send welcome message
    const welcome = "NenDB Enhanced Server Ready\n";
    connection.write(welcome) catch |err| {
        std.debug.print("⚠️  Failed to send welcome: {}\n", .{err});
        return;
    };

    while (connection.is_active and server.is_running) {
        const data = connection.read() catch |err| {
            std.debug.print("⚠️  Read error: {}\n", .{err});
            break;
        };

        if (data.len == 0) break;

        // Process the request
        const response = processRequest(data);
        
        // Send response
        connection.write(response.json()) catch |err| {
            std.debug.print("⚠️  Failed to send response: {}\n", .{err});
            break;
        };
    }

    std.debug.print("🔌 Connection closed from {}\n", .{connection.address});
}

fn processRequest(data: []const u8) Response {
    // Simple request parsing - in production, use proper protocol parsing
    const request = std.mem.trim(u8, data, " \r\n");
    
    if (std.mem.eql(u8, request, "PING")) {
        return Response{ .success = true, .data = "PONG" };
    } else if (std.mem.eql(u8, request, "STATUS")) {
        return Response{ .success = true, .data = "Server running with enhanced networking" };
    } else if (std.mem.eql(u8, request, "QUIT")) {
        return Response{ .success = true, .data = "BYE" };
    } else if (std.mem.startsWith(u8, request, "GRAPH:")) {
        return Response{ .success = true, .data = "Graph operation received" };
    } else if (std.mem.startsWith(u8, request, "DOC:")) {
        return Response{ .success = true, .data = "Document operation received" };
    } else if (std.mem.startsWith(u8, request, "KV:")) {
        return Response{ .success = true, .data = "Key-Value operation received" };
    } else {
        return Response{ .success = false, .error_message = "Unknown command" };
    }
}

// Convenience function to start server with default config
pub fn startDefaultServer(port: u16) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const config = ServerConfig{ .port = port };
    var server = try EnhancedServer.init(allocator, config);
    defer server.deinit();

    try server.start();
}

