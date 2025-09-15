// NenDB Write-Ahead Log (WAL) - Clean DOD Version
// Minimal working version with only SOA functionality

const std = @import("std");
const layout = @import("memory/layout.zig");
const constants = @import("constants.zig");

const WAL_MAGIC: u32 = 0x4E454E44; // 'NEND'
const WAL_VERSION: u16 = 1;
const HEADER_SIZE: usize = 4 + 2; // magic + version
const DEBUG_WAL = false;

pub const Wal = struct {
    file: std.fs.File,
    closed: bool = false,
    has_header: bool = false,
    read_only: bool = false,
    end_pos: u64 = 0,
    entries_written: u64 = 0,
    segment_index: u32 = 0,
    segment_size_limit: u64 = 64 * 1024 * 1024, // 64MB default

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
        wal.has_header = true;

        return wal;
    }

    pub fn openReadOnly(path: []const u8) !Wal {
        const file = try std.fs.cwd().openFile(path, .{ .mode = .read_only });

        var wal = Wal{
            .file = file,
            .closed = false,
            .read_only = true,
        };

        wal.end_pos = try file.getEndPos();
        wal.has_header = true;

        return wal;
    }

    fn writeHeader(self: *Wal) !void {
        var header: [HEADER_SIZE]u8 = undefined;
        std.mem.writeInt(u32, header[0..4], WAL_MAGIC, .little);
        std.mem.writeInt(u16, header[4..6], WAL_VERSION, .little);
        try self.file.writeAll(&header);
        try self.file.sync();
    }

    pub inline fn append_insert_node_soa(self: *Wal, id: u64, kind: u8) !void {
        if (self.read_only) return error.AccessDenied;

        // Build simplified entry buffer for SoA: [id(8) | kind(1) | crc32(4)]
        const entry_size = 8 + 1 + 4;
        var entry_buf: [entry_size]u8 = undefined;

        // Write data directly to buffer for Zig 0.15.1 compatibility
        var pos: usize = 0;

        // Write id (8 bytes, little endian) - manual byte writing
        var id_bytes: [8]u8 = undefined;
        std.mem.writeInt(u64, &id_bytes, id, .little);
        @memcpy(entry_buf[pos .. pos + 8], &id_bytes);
        pos += 8;

        // Write kind (1 byte)
        entry_buf[pos] = kind;
        pos += 1;

        // Calculate CRC32 for id + kind
        const crc = std.hash.crc.Crc32.hash(entry_buf[0..9]);

        // Write CRC32 (4 bytes, little endian) - manual byte writing
        var crc_bytes: [4]u8 = undefined;
        std.mem.writeInt(u32, &crc_bytes, crc, .little);
        @memcpy(entry_buf[pos .. pos + 4], &crc_bytes);

        // Write to file
        const off: u64 = self.end_pos;
        try self.file.pwriteAll(&entry_buf, off);
        try self.file.sync();

        self.end_pos += entry_size;
        self.entries_written += 1;
    }

    pub inline fn append_insert_edge_soa(self: *Wal, from: u64, to: u64, label: u16) !void {
        if (self.read_only) return error.AccessDenied;

        // Build entry buffer for edge: [from(8) | to(8) | label(2) | crc32(4)]
        const entry_size = 8 + 8 + 2 + 4;
        var entry_buf: [entry_size]u8 = undefined;

        // Write data directly to buffer for Zig 0.15.1 compatibility
        var pos: usize = 0;
        
        // Write from (8 bytes, little endian) - manual byte writing
        var from_bytes: [8]u8 = undefined;
        std.mem.writeInt(u64, &from_bytes, from, .little);
        @memcpy(entry_buf[pos..pos+8], &from_bytes);
        pos += 8;
        
        // Write to (8 bytes, little endian) - manual byte writing
        var to_bytes: [8]u8 = undefined;
        std.mem.writeInt(u64, &to_bytes, to, .little);
        @memcpy(entry_buf[pos..pos+8], &to_bytes);
        pos += 8;
        
        // Write label (2 bytes, little endian) - manual byte writing
        var label_bytes: [2]u8 = undefined;
        std.mem.writeInt(u16, &label_bytes, label, .little);
        @memcpy(entry_buf[pos..pos+2], &label_bytes);
        pos += 2;
        
        // Calculate CRC32 for from + to + label
        const crc = std.hash.crc.Crc32.hash(entry_buf[0..18]);
        
        // Write CRC32 (4 bytes, little endian) - manual byte writing
        var crc_bytes: [4]u8 = undefined;
        std.mem.writeInt(u32, &crc_bytes, crc, .little);
        @memcpy(entry_buf[pos..pos+4], &crc_bytes);

        // Write to file
        const off: u64 = self.end_pos;
        try self.file.pwriteAll(&entry_buf, off);
        try self.file.sync();

        self.end_pos += entry_size;
        self.entries_written += 1;
    }

    pub inline fn close(self: *Wal) void {
        if (!self.closed) {
            self.file.close();
            self.closed = true;
        }
    }

    pub fn getStats(self: *const Wal) WalStats {
        return WalStats{
            .entries_written = self.entries_written,
            .bytes_written = self.end_pos,
            .truncations = 0,
            .rotations = 0,
        };
    }

    pub fn getHealth(self: *const Wal) WalHealth {
        return WalHealth{
            .healthy = !self.closed,
            .last_error = "",
        };
    }

    pub fn delete_segments_keep_last(_: *Wal, _: u32) !u32 {
        // Simplified - no segment rotation for now
        return 0;
    }

    pub fn total_entries(self: *const Wal) !u64 {
        return self.entries_written;
    }

    pub fn truncate_to_header(self: *Wal) !void {
        if (self.read_only) return error.AccessDenied;
        try self.file.setEndPos(HEADER_SIZE);
        self.end_pos = HEADER_SIZE;
        self.entries_written = 0;
    }
};
