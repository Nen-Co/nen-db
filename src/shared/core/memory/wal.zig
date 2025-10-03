// NenDB Write-Ahead Log (WAL) - Simple Working Version
// Minimal implementation for persistence

const std = @import("std");
const constants = @import("../constants.zig");

const WAL_MAGIC: u32 = 0x4E454E44; // 'NEND'
const WAL_VERSION: u16 = 1;
const HEADER_SIZE: usize = 4 + 2; // magic + version

pub const Wal = struct {
    file: std.fs.File,
    closed: bool = false,
    has_header: bool = false,
    read_only: bool = false,
    end_pos: u64 = 0,
    entries_written: u64 = 0,
    // Buffered I/O to minimize syscalls
    buf: [64 * 1024]u8 = undefined,
    buf_len: usize = 0,

    pub const WalStats = struct {
        entries_written: u64,
        bytes_written: u64,
        truncations: u64,
        rotations: u64,
    };

    pub const WalHealth = struct {
        healthy: bool,
        last_error: []const u8,
    };

    pub fn open(path: []const u8) !Wal {
        const file = try std.fs.cwd().createFile(path, .{ .read = true, .truncate = false });

        var wal = Wal{
            .file = file,
            .closed = false,
            .read_only = false,
        };

        // Initialize WAL with header if needed
        const file_size = try file.getEndPos();
        if (file_size == 0) {
            try wal.writeHeader();
            wal.end_pos = HEADER_SIZE;
        } else {
            wal.end_pos = file_size;
        }

        return wal;
    }

    fn writeHeader(self: *Wal) !void {
        var header: [HEADER_SIZE]u8 = undefined;
        std.mem.writeInt(u32, header[0..4], WAL_MAGIC, .little);
        std.mem.writeInt(u16, header[4..6], WAL_VERSION, .little);

        _ = try self.file.writeAll(&header);
        self.has_header = true;
    }

    pub fn close(self: *Wal) void {
        if (!self.closed) {
            // Flush remaining buffer before closing
            _ = self.flush() catch {};
            self.file.close();
            self.closed = true;
        }
    }

    pub fn getHealth(self: *const Wal) WalHealth {
        return WalHealth{
            .healthy = !self.closed,
            .last_error = "",
        };
    }

    pub fn getStats(self: *const Wal) WalStats {
        return WalStats{
            .entries_written = self.entries_written,
            .bytes_written = self.end_pos + self.buf_len,
            .truncations = 0,
            .rotations = 0,
        };
    }

    // Simple node insert logging
    pub fn write_node_insert(self: *Wal, id: u64, kind: u8) !void {
        var entry: [16]u8 = undefined;
        std.mem.writeInt(u64, entry[0..8], id, .little);
        std.mem.writeInt(u64, entry[8..16], @as(u64, kind), .little);

        try self.append_to_buffer(&entry);
        self.entries_written += 1;
    }

    // Simple edge insert logging
    pub fn write_edge_insert(self: *Wal, from: u64, to: u64, label: u8) !void {
        var entry: [24]u8 = undefined;
        std.mem.writeInt(u64, entry[0..8], from, .little);
        std.mem.writeInt(u64, entry[8..16], to, .little);
        std.mem.writeInt(u64, entry[16..24], @as(u64, label), .little);

        try self.append_to_buffer(&entry);
        self.entries_written += 1;
    }

    // Alias for compatibility
    pub fn append_insert_node_soa(self: *Wal, id: u64, kind: u8) !void {
        try self.write_node_insert(id, kind);
    }

    pub fn append_insert_edge_soa(self: *Wal, from: u64, to: u64, label: u16) !void {
        try self.write_edge_insert(from, to, @as(u8, @truncate(label)));
    }

    // Simple segment management
    pub fn delete_segments_keep_last(self: *Wal, keep_count: u32) !void {
        // For now, just a no-op - in a real implementation this would manage segments
        _ = self;
        _ = keep_count;
    }

    fn append_to_buffer(self: *Wal, bytes: []const u8) !void {
        if (bytes.len > self.buf.len) {
            // Entry too large for buffer; write directly
            _ = try self.file.writeAll(bytes);
            self.end_pos += bytes.len;
            return;
        }

        if (self.buf_len + bytes.len > self.buf.len) {
            try self.flush();
        }

        @memcpy(self.buf[self.buf_len .. self.buf_len + bytes.len], bytes);
        self.buf_len += bytes.len;
    }

    pub fn flush(self: *Wal) !void {
        if (self.buf_len == 0) return;
        _ = try self.file.writeAll(self.buf[0..self.buf_len]);
        self.end_pos += self.buf_len;
        self.buf_len = 0;
    }
};
