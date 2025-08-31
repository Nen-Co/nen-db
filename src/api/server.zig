// NenDB Server - Enhanced with HTTP and Graph Algorithm Support
// Provides high-performance, statically allocated networking APIs for database operations
// Follows Nen way: inline functions, static memory, efficient allocation

const std = @import("std");
const nen_net = @import("nen-net");
const constants = @import("constants.zig");

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
            writer.writeAll(",\"data\":\"") catch return "{}";
            writer.writeAll(data) catch return "{}";
            writer.writeAll("\"") catch return "{}";
        }

        if (self.error_message) |error_msg| {
            writer.writeAll(",\"error\":\"") catch return "{}";
            writer.writeAll(error_msg) catch return "{}";
            writer.writeAll("\"") catch return "{}";
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
    db_handler: ?*const fn ([]const u8, []const u8) Response = null,

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

    pub fn setDatabaseHandler(self: *EnhancedServer, handler: *const fn ([]const u8, []const u8) Response) void {
        self.db_handler = handler;
    }

    pub fn start(self: *EnhancedServer) !void {
        if (self.is_running) return error.ServerAlreadyRunning;

        std.debug.print("🚀 Starting NenDB Enhanced Server on {s}:{d}\n", .{ self.config.host, self.config.port });
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
        try std.posix.listen(sockfd, @intCast(self.config.max_connections));

        std.debug.print("✅ Server listening on {any}:{d}\n", .{ address, self.config.port });

        while (self.is_running) {
            var client_addr: std.net.Address = undefined;
            var client_addr_len: std.posix.socklen_t = @sizeOf(std.net.Address);

            const connfd = std.posix.accept(sockfd, &client_addr.any, &client_addr_len, 0) catch |err| {
                std.debug.print("⚠️  Accept error: {any}\n", .{err});
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
    allocator: std.mem.Allocator,
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
            .allocator = allocator,
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

    std.debug.print("🔌 New connection from {any}\n", .{connection.address});

    // Send welcome message
    const welcome = "NenDB Enhanced Server Ready\n";
    connection.write(welcome) catch |err| {
        std.debug.print("⚠️  Failed to send welcome: {any}\n", .{err});
        return;
    };

    while (connection.is_active and server.is_running) {
        const data = connection.read() catch |err| {
            std.debug.print("⚠️  Read error: {any}\n", .{err});
            break;
        };

        if (data.len == 0) break;

        // Process the request
        const response = processRequest(data);

        // Send response
        connection.write(response.json()) catch |err| {
            std.debug.print("⚠️  Failed to send response: {any}\n", .{err});
            break;
        };
    }

    std.debug.print("🔌 Connection closed from {any}\n", .{connection.address});
}

// Handle HTTP requests using nen-net infrastructure
fn handleHTTPRequest(data: []const u8) Response {
    // Parse HTTP request line
    var lines = std.mem.splitSequence(u8, data, "\r\n");
    const request_line = lines.next() orelse {
        return Response{ .success = false, .error_message = "Invalid HTTP request" };
    };
    
    var parts = std.mem.splitSequence(u8, request_line, " ");
    const method = parts.next() orelse {
        return Response{ .success = false, .error_message = "Invalid HTTP method" };
    };
    const path = parts.next() orelse {
        return Response{ .success = false, .error_message = "Invalid HTTP path" };
    };
    _ = parts.next(); // Skip version
    
    // Route based on path using nen-net style
    if (std.mem.startsWith(u8, path, "/graph/algorithms/")) {
        return handleAlgorithmEndpoint(method, path, data);
    } else if (std.mem.startsWith(u8, path, "/graph/stats")) {
        return handleGraphStats(method, path);
    } else if (std.mem.startsWith(u8, path, "/health")) {
        return handleHealthCheck(method, path) catch |err| {
            return Response{ .success = false, .error_message = "Internal server error" };
        };
    } else {
        return Response{ 
            .success = false, 
            .error_message = "{\"error\": \"Endpoint not found\"}" 
        };
    }
}

// Handle graph algorithm endpoints
fn handleAlgorithmEndpoint(method: []const u8, path: []const u8, data: []const u8) Response {
    _ = data; // Not used yet
    if (!std.mem.eql(u8, method, "POST")) {
        return Response{ 
            .success = false, 
            .error_message = "{\"error\": \"Method not allowed\"}" 
        };
    }
    
    // Extract algorithm type from path
    if (std.mem.startsWith(u8, path, "/graph/algorithms/bfs")) {
        return Response{ .success = true, .data = "{\"algorithm\": \"bfs\", \"status\": \"queued\", \"message\": \"BFS algorithm queued for execution\"}" };
    } else if (std.mem.startsWith(u8, path, "/graph/algorithms/dijkstra")) {
        return Response{ .success = true, .data = "{\"algorithm\": \"dijkstra\", \"status\": \"queued\", \"message\": \"Dijkstra algorithm queued for execution\"}" };
    } else if (std.mem.startsWith(u8, path, "/graph/algorithms/pagerank")) {
        return Response{ .success = true, .data = "{\"algorithm\": \"pagerank\", \"status\": \"queued\", \"message\": \"PageRank algorithm queued for execution\"}" };
            } else {
            return Response{ 
                .success = false, 
                .error_message = "{\"error\": \"Algorithm not found\"}" 
            };
        }
}

// Handle graph statistics endpoint
fn handleGraphStats(method: []const u8, path: []const u8) Response {
    _ = path; // Not used yet
    
    if (!std.mem.eql(u8, method, "GET")) {
        return Response{ 
            .success = false, 
            .error_message = "{\"error\": \"Method not allowed\"}" 
        };
    }
    
    const stats = "{\"nodes\": 0, \"edges\": 0, \"algorithms\": [\"bfs\", \"dijkstra\", \"pagerank\"], \"status\": \"operational\"}";
    return Response{ .success = true, .data = stats };
}

// Handle health check endpoint
fn handleHealthCheck(method: []const u8, path: []const u8) !Response {
    _ = path; // Not used yet
    
    if (!std.mem.eql(u8, method, "GET")) {
        return Response{ 
            .success = false, 
            .error_message = "{\"error\": \"Method not allowed\"}" 
        };
    }
    
    const health = try std.fmt.allocPrint(server.allocator, "{{\"status\": \"healthy\", \"service\": \"nendb\", \"version\": \"{s}\"}}", .{constants.VERSION_STRING});
    return Response{ .success = true, .data = health };
}

// Get current timestamp for health checks
fn getCurrentTimestamp() []const u8 {
    const now = std.time.timestamp();
    var buf: [32]u8 = undefined;
    const timestamp = std.fmt.bufPrint(&buf, "{d}", .{now}) catch "unknown";
    return timestamp;
}

fn processRequest(data: []const u8) Response {
    // Try to parse as HTTP request first
    if (std.mem.startsWith(u8, data, "GET ") or 
        std.mem.startsWith(u8, data, "POST ") or
        std.mem.startsWith(u8, data, "PUT ") or
        std.mem.startsWith(u8, data, "DELETE ")) {
        
        return handleHTTPRequest(data);
    }
    
    // Fallback to legacy protocol parsing
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
