// NenDB Write-Ahead Log (WAL)
// Production-grade persistence following TigerBeetle patterns

const std = @import("std");
const constants = @import("../constants.zig");
const pool = @import("pool_v2.zig");

// WAL Operation Types
pub const WALOpType = enum(u8) {
    node_insert = 1,
    node_update = 2,
    node_delete = 3,
    edge_insert = 4,
    edge_update = 5,
    edge_delete = 6,
    embedding_insert = 7,
    embedding_update = 8,
    embedding_delete = 9,
    checkpoint = 255,
};

// WAL Entry Header (fixed size for performance)
pub const WALHeader = extern struct {
    magic: u32 = 0x4E454E57, // "NENW" in hex
    op_type: WALOpType,
    timestamp: u64,
    size: u32,
    checksum: u32,
    reserved: [7]u8 = [_]u8{0} ** 7,
    
    comptime {
        std.debug.assert(@sizeOf(WALHeader) == 32); // Keep aligned
    }
};

// WAL Entry (header + data)
pub const WALEntry = struct {
    header: WALHeader,
    data: []const u8,
    
    pub fn calculate_checksum(self: *const WALEntry) u32 {
        var crc = std.hash.Crc32.init();
        crc.update(std.mem.asBytes(&self.header.op_type));
        crc.update(std.mem.asBytes(&self.header.timestamp));
        crc.update(std.mem.asBytes(&self.header.size));
        crc.update(self.data);
        return crc.final();
    }
    
    pub fn verify_checksum(self: *const WALEntry) bool {
        return self.header.checksum == self.calculate_checksum();
    }
};

// WAL Manager - Production-grade logging
pub const WAL = struct {
    const Self = @This();
    
    // File handles
    file: ?std.fs.File = null,
    allocator: std.mem.Allocator,
    
    // Configuration
    segment_size: u64,
    max_segments: u32,
    sync_interval: u32,
    
    // State
    current_segment: u32 = 0,
    operations_since_sync: u32 = 0,
    
    // Buffer for batched writes (TigerBeetle pattern)
    write_buffer: [constants.memory.batch_max * @sizeOf(WALHeader)]u8 = undefined,
    buffer_used: u32 = 0,
    
    pub fn init(allocator: std.mem.Allocator, data_dir: []const u8) !Self {
        var self = Self{
            .allocator = allocator,
            .segment_size = constants.storage.wal_segment_size,
            .max_segments = constants.storage.wal_max_segments,
            .sync_interval = constants.storage.sync_interval,
        };
        
        // Ensure data directory exists
        std.fs.cwd().makeDir(data_dir) catch |err| switch (err) {
            error.PathAlreadyExists => {},
            else => return err,
        };
        
        // Open current WAL file
        try self.open_current_segment(data_dir);
        
        return self;
    }
    
    pub fn deinit(self: *Self) void {
        self.flush() catch {};
        if (self.file) |file| {
            file.close();
        }
    }
    
    fn open_current_segment(self: *Self, data_dir: []const u8) !void {
        const file_path = try std.fmt.allocPrint(
            self.allocator,
            "{s}/wal_{d:0>6}.log",
            .{ data_dir, self.current_segment }
        );
        defer self.allocator.free(file_path);
        
        self.file = try std.fs.cwd().createFile(file_path, .{
            .truncate = false,
            .read = true,
        });
        
        // Seek to end for appending
        try self.file.?.seekFromEnd(0);
    }
    
    pub fn write_node_insert(self: *Self, node: pool.Node) !void {
        var header = WALHeader{
            .op_type = .node_insert,
            .timestamp = @intCast(std.time.nanoTimestamp()),
            .size = @sizeOf(pool.Node),
            .checksum = 0,
        };
        
        const entry = WALEntry{
            .header = header,
            .data = std.mem.asBytes(&node),
        };
        
        // Update checksum
        header.checksum = entry.calculate_checksum();
        
        try self.write_entry(WALEntry{
            .header = header,
            .data = entry.data,
        });
    }
    
    pub fn write_edge_insert(self: *Self, edge: pool.Edge) !void {
        var header = WALHeader{
            .op_type = .edge_insert,
            .timestamp = @intCast(std.time.nanoTimestamp()),
            .size = @sizeOf(pool.Edge),
            .checksum = 0,
        };
        
        const entry = WALEntry{
            .header = header,
            .data = std.mem.asBytes(&edge),
        };
        
        header.checksum = entry.calculate_checksum();
        
        try self.write_entry(WALEntry{
            .header = header,
            .data = entry.data,
        });
    }
    
    pub fn write_checkpoint(self: *Self) !void {
        const header = WALHeader{
            .op_type = .checkpoint,
            .timestamp = @intCast(std.time.nanoTimestamp()),
            .size = 0,
            .checksum = 0, // No data to checksum
        };
        
        try self.write_entry(WALEntry{
            .header = header,
            .data = &[_]u8{},
        });
        
        try self.flush();
    }
    
    fn write_entry(self: *Self, entry: WALEntry) !void {
        if (self.file == null) return constants.NenDBError.IOError;
        
        const total_size = @sizeOf(WALHeader) + entry.data.len;
        
        // Check if we need to flush buffer
        if (self.buffer_used + total_size > self.write_buffer.len) {
            try self.flush();
        }
        
        // Write to buffer for batching
        const header_bytes = std.mem.asBytes(&entry.header);
        @memcpy(self.write_buffer[self.buffer_used..self.buffer_used + header_bytes.len], header_bytes);
        self.buffer_used += @intCast(header_bytes.len);
        
        if (entry.data.len > 0) {
            @memcpy(self.write_buffer[self.buffer_used..self.buffer_used + entry.data.len], entry.data);
            self.buffer_used += @intCast(entry.data.len);
        }
        
        self.operations_since_sync += 1;
        
        // Auto-flush based on sync interval
        if (self.operations_since_sync >= self.sync_interval) {
            try self.flush();
        }
    }
    
    pub fn flush(self: *Self) !void {
        if (self.file == null or self.buffer_used == 0) return;
        
        // Write buffer to disk
        _ = try self.file.?.writeAll(self.write_buffer[0..self.buffer_used]);
        
        // Sync to ensure durability (TigerBeetle's approach)
        try self.file.?.sync();
        
        // Reset buffer
        self.buffer_used = 0;
        self.operations_since_sync = 0;
    }
    
    // Recovery functionality
    pub fn replay(self: *Self, data_dir: []const u8, node_pool: *pool.NodePool, edge_pool: *pool.EdgePool) !u32 {
        var operations_replayed: u32 = 0;
        
        // Find all WAL segments
        var dir = try std.fs.cwd().openDir(data_dir, .{ .iterate = true });
        defer dir.close();
        
        var iterator = dir.iterate();
        while (try iterator.next()) |entry| {
            if (std.mem.startsWith(u8, entry.name, "wal_") and std.mem.endsWith(u8, entry.name, ".log")) {
                operations_replayed += try self.replay_segment(data_dir, entry.name, node_pool, edge_pool);
            }
        }
        
        return operations_replayed;
    }
    
    fn replay_segment(self: *Self, data_dir: []const u8, filename: []const u8, node_pool: *pool.NodePool, edge_pool: *pool.EdgePool) !u32 {
        const file_path = try std.fmt.allocPrint(self.allocator, "{s}/{s}", .{ data_dir, filename });
        defer self.allocator.free(file_path);
        
        var file = try std.fs.cwd().openFile(file_path, .{});
        defer file.close();
        
        var operations_replayed: u32 = 0;
        var buffer: [4096]u8 = undefined;
        
        while (true) {
            // Read WAL header
            const header_bytes = file.readAll(buffer[0..@sizeOf(WALHeader)]) catch |err| switch (err) {
                else => return err,
            };
            
            if (header_bytes < @sizeOf(WALHeader)) break;
            
            const header = std.mem.bytesToValue(WALHeader, buffer[0..@sizeOf(WALHeader)]);
            
            // Verify magic number
            if (header.magic != 0x4E454E57) return constants.NenDBError.CorruptedData;
            
            // Read data if present
            var data: []u8 = undefined;
            if (header.size > 0) {
                if (header.size > buffer.len - @sizeOf(WALHeader)) return constants.NenDBError.CorruptedData;
                
                const data_bytes = try file.readAll(buffer[@sizeOf(WALHeader)..@sizeOf(WALHeader) + header.size]);
                if (data_bytes != header.size) return constants.NenDBError.CorruptedData;
                
                data = buffer[@sizeOf(WALHeader)..@sizeOf(WALHeader) + header.size];
            }
            
            // Replay operation
            switch (header.op_type) {
                .node_insert => {
                    if (data.len != @sizeOf(pool.Node)) return constants.NenDBError.CorruptedData;
                    const node = std.mem.bytesToValue(pool.Node, data[0..@sizeOf(pool.Node)]);
                    _ = node_pool.alloc(node) catch continue; // Skip if pool full during replay
                },
                .edge_insert => {
                    if (data.len != @sizeOf(pool.Edge)) return constants.NenDBError.CorruptedData;
                    const edge = std.mem.bytesToValue(pool.Edge, data[0..@sizeOf(pool.Edge)]);
                    _ = edge_pool.alloc(edge) catch continue; // Skip if pool full during replay
                },
                .checkpoint => {
                    // Checkpoint marker, no action needed
                },
                else => {
                    // Unknown operation, skip
                    continue;
                },
            }
            
            operations_replayed += 1;
        }
        
        return operations_replayed;
    }
};
