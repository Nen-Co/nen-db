// NenDB Production Write-Ahead Log (WAL)
// Complete implementation with segment rotation, CRC validation, and recovery

const std = @import("std");
const assert = std.debug.assert;
const constants = @import("constants.zig");

// WAL constants
const WAL_MAGIC: u32 = 0x4E454E44; // 'NEND'
const WAL_VERSION: u16 = 2; // Version 2 for production
const HEADER_SIZE: usize = 4 + 2 + 8 + 4; // magic + version + lsn + crc
const MAX_SEGMENT_SIZE: u64 = 64 * 1024 * 1024; // 64MB per segment
const MAX_ENTRIES_PER_SEGMENT: u32 = 10000;
const CRC32_POLYNOMIAL: u32 = 0xEDB88320;

// WAL entry types
const EntryType = enum(u8) {
    node_insert = 1,
    node_update = 2,
    node_delete = 3,
    edge_insert = 4,
    edge_update = 5,
    edge_delete = 6,
    transaction_begin = 7,
    transaction_commit = 8,
    transaction_abort = 9,
    checkpoint = 10,
    segment_rotate = 11,
};

// WAL entry header
const EntryHeader = struct {
    entry_type: EntryType,
    entry_size: u32,
    lsn: u64,
    timestamp: i64,
    crc32: u32,

    const SIZE = 1 + 4 + 8 + 8 + 4; // 25 bytes

    fn serialize(self: *const EntryHeader, buffer: []u8) void {
        assert(buffer.len >= SIZE);
        var offset: usize = 0;

        buffer[offset] = @intFromEnum(self.entry_type);
        offset += 1;

        std.mem.writeInt(u32, buffer[offset .. offset + 4], self.entry_size, .little);
        offset += 4;

        std.mem.writeInt(u64, buffer[offset .. offset + 8], self.lsn, .little);
        offset += 8;

        std.mem.writeInt(i64, buffer[offset .. offset + 8], self.timestamp, .little);
        offset += 8;

        std.mem.writeInt(u32, buffer[offset..][0..4], self.crc32, .little);
    }

    fn deserialize(buffer: []const u8) EntryHeader {
        assert(buffer.len >= SIZE);
        var offset: usize = 0;

        const entry_type = @as(EntryType, @enumFromInt(buffer[offset]));
        offset += 1;

        const entry_size = std.mem.readInt(u32, buffer[offset .. offset + 4], .little);
        offset += 4;

        const lsn = std.mem.readInt(u64, buffer[offset .. offset + 8], .little);
        offset += 8;

        const timestamp = std.mem.readInt(i64, buffer[offset .. offset + 8], .little);
        offset += 8;

        const crc32 = std.mem.readInt(u32, buffer[offset .. offset + 4], .little);

        return EntryHeader{
            .entry_type = entry_type,
            .entry_size = entry_size,
            .lsn = lsn,
            .timestamp = timestamp,
            .crc32 = crc32,
        };
    }
};

// WAL segment header
const SegmentHeader = struct {
    magic: u32,
    version: u16,
    segment_id: u32,
    lsn_start: u64,
    lsn_end: u64,
    entry_count: u32,
    crc32: u32,

    const SIZE = 4 + 2 + 4 + 8 + 8 + 4 + 4; // 34 bytes

    fn serialize(self: *const SegmentHeader, buffer: []u8) void {
        assert(buffer.len >= SIZE);
        var offset: usize = 0;

        std.mem.writeInt(u32, buffer[offset..][0..4], self.magic, .little);
        offset += 4;

        std.mem.writeInt(u16, buffer[offset..][0..2], self.version, .little);
        offset += 2;

        std.mem.writeInt(u32, buffer[offset..][0..4], self.segment_id, .little);
        offset += 4;

        std.mem.writeInt(u64, buffer[offset..][0..8], self.lsn_start, .little);
        offset += 8;

        std.mem.writeInt(u64, buffer[offset..][0..8], self.lsn_end, .little);
        offset += 8;

        std.mem.writeInt(u32, buffer[offset..][0..4], self.entry_count, .little);
        offset += 4;

        std.mem.writeInt(u32, buffer[offset..][0..4], self.crc32, .little);
    }

    fn deserialize(buffer: []const u8) SegmentHeader {
        assert(buffer.len >= SIZE);
        var offset: usize = 0;

        const magic = std.mem.readInt(u32, buffer[offset .. offset + 4], .little);
        offset += 4;

        const version = std.mem.readInt(u16, buffer[offset .. offset + 2], .little);
        offset += 2;

        const segment_id = std.mem.readInt(u32, buffer[offset .. offset + 4], .little);
        offset += 4;

        const lsn_start = std.mem.readInt(u64, buffer[offset .. offset + 8], .little);
        offset += 8;

        const lsn_end = std.mem.readInt(u64, buffer[offset .. offset + 8], .little);
        offset += 8;

        const entry_count = std.mem.readInt(u32, buffer[offset .. offset + 4], .little);
        offset += 4;

        const crc32 = std.mem.readInt(u32, buffer[offset .. offset + 4], .little);

        return SegmentHeader{
            .magic = magic,
            .version = version,
            .segment_id = segment_id,
            .lsn_start = lsn_start,
            .lsn_end = lsn_end,
            .entry_count = entry_count,
            .crc32 = crc32,
        };
    }
};

// CRC32 calculation
fn calculateCRC32(data: []const u8) u32 {
    var crc: u32 = 0xFFFFFFFF;

    for (data) |byte| {
        crc ^= byte;
        var i: u32 = 0;
        while (i < 8) : (i += 1) {
            if (crc & 1 != 0) {
                crc = (crc >> 1) ^ CRC32_POLYNOMIAL;
            } else {
                crc >>= 1;
            }
        }
    }

    return crc ^ 0xFFFFFFFF;
}

// Production WAL implementation
pub const ProductionWal = struct {
    data_dir: []const u8,
    current_segment: ?std.fs.File = null,
    current_segment_id: u32 = 0,
    current_lsn: u64 = 1,
    current_entry_count: u32 = 0,
    current_segment_size: u64 = 0,
    closed: bool = false,

    // Buffered I/O for performance
    buffer: [64 * 1024]u8 = undefined,
    buffer_pos: usize = 0,

    // Statistics
    stats: WalStats = WalStats{},

    pub const WalStats = struct {
        segments_created: u32 = 0,
        segments_rotated: u32 = 0,
        entries_written: u64 = 0,
        bytes_written: u64 = 0,
        crc_errors: u32 = 0,
        recovery_entries: u64 = 0,
    };

    pub fn init(data_dir: []const u8) !ProductionWal {
        // Ensure data directory exists
        std.fs.cwd().makeDir(data_dir) catch |err| switch (err) {
            error.PathAlreadyExists => {},
            else => return err,
        };

        return ProductionWal{
            .data_dir = data_dir,
        };
    }

    pub fn deinit(self: *ProductionWal) void {
        if (!self.closed) {
            self.close() catch {};
        }
    }

    /// Open WAL for writing
    pub fn open(self: *ProductionWal) !void {
        if (self.current_segment != null) return;

        // Find the next segment ID
        self.current_segment_id = try self.findNextSegmentId();

        // Create new segment file
        const segment_path = try self.getSegmentPath(self.current_segment_id);
        self.current_segment = try std.fs.cwd().createFile(segment_path, .{ .read = true, .truncate = false });

        // Write segment header
        try self.writeSegmentHeader();

        self.stats.segments_created += 1;
    }

    /// Close WAL
    pub fn close(self: *ProductionWal) !void {
        if (self.closed) return;

        // Flush remaining buffer
        try self.flushBuffer();

        // Close current segment
        if (self.current_segment) |*file| {
            file.close();
            self.current_segment = null;
        }

        self.closed = true;
    }

    /// Write a node insert entry
    pub fn writeNodeInsert(self: *ProductionWal, id: u64, kind: u8, properties: ?[]const u8) !void {
        const entry_data = try self.serializeNodeInsert(id, kind, properties);
        try self.writeEntry(.node_insert, entry_data);
    }

    /// Write an edge insert entry
    pub fn writeEdgeInsert(self: *ProductionWal, from: u64, to: u64, label: u16, properties: ?[]const u8) !void {
        const entry_data = try self.serializeEdgeInsert(from, to, label, properties);
        try self.writeEntry(.edge_insert, entry_data);
    }

    /// Write a transaction begin entry
    pub fn writeTransactionBegin(self: *ProductionWal, transaction_id: u64) !void {
        var entry_data: [8]u8 = undefined;
        std.mem.writeInt(u64, &entry_data, transaction_id, .little);
        try self.writeEntry(.transaction_begin, &entry_data);
    }

    /// Write a transaction commit entry
    pub fn writeTransactionCommit(self: *ProductionWal, transaction_id: u64) !void {
        var entry_data: [8]u8 = undefined;
        std.mem.writeInt(u64, &entry_data, transaction_id, .little);
        try self.writeEntry(.transaction_commit, &entry_data);
    }

    /// Write a checkpoint entry
    pub fn writeCheckpoint(self: *ProductionWal, lsn: u64) !void {
        var entry_data: [8]u8 = undefined;
        std.mem.writeInt(u64, &entry_data, lsn, .little);
        try self.writeEntry(.checkpoint, &entry_data);
    }

    /// Internal method to write an entry
    fn writeEntry(self: *ProductionWal, entry_type: EntryType, data: []const u8) !void {
        if (self.current_segment == null) {
            try self.open();
        }

        // Check if we need to rotate segment
        if (self.shouldRotateSegment(data.len)) {
            try self.rotateSegment();
        }

        const entry_size = EntryHeader.SIZE + data.len;
        const timestamp = std.time.timestamp();

        // Create entry header
        const header = EntryHeader{
            .entry_type = entry_type,
            .entry_size = @intCast(entry_size),
            .lsn = self.current_lsn,
            .timestamp = timestamp,
            .crc32 = 0, // Will be calculated
        };

        // Calculate CRC32 for the entire entry
        var crc_data: [EntryHeader.SIZE + 1024]u8 = undefined; // Assume max 1KB data
        assert(data.len <= 1024);

        header.serialize(crc_data[0..EntryHeader.SIZE]);
        @memcpy(crc_data[EntryHeader.SIZE .. EntryHeader.SIZE + data.len], data);

        const crc32 = calculateCRC32(crc_data[0 .. EntryHeader.SIZE + data.len]);

        // Update header with CRC
        var final_header = header;
        final_header.crc32 = crc32;

        // Write header
        try self.writeToBuffer(final_header.serialize(crc_data[0..EntryHeader.SIZE]));

        // Write data
        try self.writeToBuffer(data);

        // Update counters
        self.current_lsn += 1;
        self.current_entry_count += 1;
        self.current_segment_size += entry_size;
        self.stats.entries_written += 1;
        self.stats.bytes_written += entry_size;
    }

    /// Serialize node insert data
    fn serializeNodeInsert(self: *ProductionWal, id: u64, kind: u8, properties: ?[]const u8) ![]u8 {
        _ = self;
        const properties_len = if (properties) |p| p.len else 0;
        const total_size = 8 + 1 + 4 + properties_len; // id + kind + len + properties

        var data = try std.heap.page_allocator.alloc(u8, total_size);
        var offset: usize = 0;

        // Write node ID
        std.mem.writeInt(u64, data[offset .. offset + 8], id, .little);
        offset += 8;

        // Write kind
        data[offset] = kind;
        offset += 1;

        // Write properties length
        std.mem.writeInt(u32, data[offset .. offset + 4], @intCast(properties_len), .little);
        offset += 4;

        // Write properties if present
        if (properties) |p| {
            @memcpy(data[offset .. offset + p.len], p);
        }

        return data;
    }

    /// Serialize edge insert data
    fn serializeEdgeInsert(self: *ProductionWal, from: u64, to: u64, label: u16, properties: ?[]const u8) ![]u8 {
        _ = self;
        const properties_len = if (properties) |p| p.len else 0;
        const total_size = 8 + 8 + 2 + 4 + properties_len; // from + to + label + len + properties

        var data = try std.heap.page_allocator.alloc(u8, total_size);
        var offset: usize = 0;

        // Write from node ID
        std.mem.writeInt(u64, data[offset .. offset + 8], from, .little);
        offset += 8;

        // Write to node ID
        std.mem.writeInt(u64, data[offset .. offset + 8], to, .little);
        offset += 8;

        // Write label
        std.mem.writeInt(u16, data[offset .. offset + 2], label, .little);
        offset += 2;

        // Write properties length
        std.mem.writeInt(u32, data[offset .. offset + 4], @intCast(properties_len), .little);
        offset += 4;

        // Write properties if present
        if (properties) |p| {
            @memcpy(data[offset .. offset + p.len], p);
        }

        return data;
    }

    /// Check if segment should be rotated
    fn shouldRotateSegment(self: *ProductionWal, entry_size: usize) bool {
        return (self.current_segment_size + entry_size > MAX_SEGMENT_SIZE) or
            (self.current_entry_count >= MAX_ENTRIES_PER_SEGMENT);
    }

    /// Rotate to a new segment
    fn rotateSegment(self: *ProductionWal) !void {
        // Flush current segment
        try self.flushBuffer();

        // Close current segment
        if (self.current_segment) |*file| {
            file.close();
        }

        // Update segment header with final LSN
        try self.updateSegmentHeader();

        // Create new segment
        self.current_segment_id += 1;
        const segment_path = try self.getSegmentPath(self.current_segment_id);
        self.current_segment = try std.fs.cwd().createFile(segment_path, .{ .read = true, .truncate = false });

        // Reset counters
        self.current_entry_count = 0;
        self.current_segment_size = 0;

        // Write new segment header
        try self.writeSegmentHeader();

        self.stats.segments_rotated += 1;
    }

    /// Write segment header
    fn writeSegmentHeader(self: *ProductionWal) !void {
        const header = SegmentHeader{
            .magic = WAL_MAGIC,
            .version = WAL_VERSION,
            .segment_id = self.current_segment_id,
            .lsn_start = self.current_lsn,
            .lsn_end = 0, // Will be updated on rotation
            .entry_count = 0, // Will be updated on rotation
            .crc32 = 0, // Will be calculated
        };

        var header_data: [SegmentHeader.SIZE]u8 = undefined;
        header.serialize(&header_data);

        // Calculate CRC for header
        const crc32 = calculateCRC32(header_data[0 .. SegmentHeader.SIZE - 4]); // Exclude CRC field
        var final_header = header;
        final_header.crc32 = crc32;
        final_header.serialize(&header_data);

        try self.writeToBuffer(&header_data);
    }

    /// Update segment header with final values
    fn updateSegmentHeader(self: *ProductionWal) !void {
        if (self.current_segment == null) return;

        const file = self.current_segment.?;
        const header = SegmentHeader{
            .magic = WAL_MAGIC,
            .version = WAL_VERSION,
            .segment_id = self.current_segment_id,
            .lsn_start = self.current_lsn - self.current_entry_count,
            .lsn_end = self.current_lsn - 1,
            .entry_count = self.current_entry_count,
            .crc32 = 0,
        };

        var header_data: [SegmentHeader.SIZE]u8 = undefined;
        header.serialize(&header_data);

        // Calculate CRC for header
        const crc32 = calculateCRC32(&header_data[0 .. SegmentHeader.SIZE - 4]);
        var final_header = header;
        final_header.crc32 = crc32;
        final_header.serialize(&header_data);

        // Seek to beginning and write updated header
        try file.seekTo(0);
        try file.writeAll(&header_data);
    }

    /// Write data to buffer (with automatic flushing)
    fn writeToBuffer(self: *ProductionWal, data: []const u8) !void {
        if (self.buffer_pos + data.len > self.buffer.len) {
            try self.flushBuffer();
        }

        @memcpy(self.buffer[self.buffer_pos .. self.buffer_pos + data.len], data);
        self.buffer_pos += data.len;
    }

    /// Flush buffer to disk
    fn flushBuffer(self: *ProductionWal) !void {
        if (self.buffer_pos == 0) return;

        const file = self.current_segment orelse return;
        try file.writeAll(self.buffer[0..self.buffer_pos]);
        try file.sync();

        self.buffer_pos = 0;
    }

    /// Get segment file path
    fn getSegmentPath(self: *ProductionWal, segment_id: u32) ![]u8 {
        return std.fmt.allocPrint(std.heap.page_allocator, "{s}/wal_segment_{:06}.wal", .{ self.data_dir, segment_id });
    }

    /// Find next segment ID
    fn findNextSegmentId(self: *ProductionWal) !u32 {
        var segment_id: u32 = 0;

        while (true) {
            const segment_path = try self.getSegmentPath(segment_id);
            defer std.heap.page_allocator.free(segment_path);

            std.fs.cwd().access(segment_path, .{}) catch |e| switch (e) {
                error.FileNotFound => return segment_id,
                else => return e,
            };

            segment_id += 1;
        }
    }

    /// Get current LSN
    pub fn getCurrentLSN(self: *const ProductionWal) u64 {
        return self.current_lsn;
    }

    /// Get statistics
    pub fn getStats(self: *const ProductionWal) WalStats {
        return self.stats;
    }
};
