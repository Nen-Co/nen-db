const std = @import("std");
const pool = @import("memory/pool_v2.zig");
const constants = @import("constants.zig");

const WAL_MAGIC: u32 = 0x4E454E44; // 'NEND'
const WAL_VERSION: u16 = 1;
const HEADER_SIZE: usize = 4 + 2; // magic + version
const DEBUG_WAL = false;
const builtin = @import("builtin");

pub const Wal = struct {
    file: std.fs.File,
    closed: bool = false,
    has_header: bool = false,
    read_only: bool = false,
    // Preallocated entry buffer (id + kind + props + crc32)
    entry_buf: [8 + 1 + pool.constants.data.node_props_size + 4]u8 = undefined,
    entries_since_sync: u32 = 0,
    sync_every: u32 = pool.constants.storage.sync_interval,
    entries_written: u64 = 0,
    entries_replayed: u64 = 0,
    truncations: u32 = 0,
    bytes_written: u64 = 0,
    end_pos: u64 = 0, // not relied on for correctness; informational only
    segment_entries: u64 = 0,
    // basic health/error tracking
    io_error_count: u32 = 0,
    last_error: ?anyerror = null,
    // rotation
    segment_size_limit: u64 = constants.storage.wal_segment_size,
    segment_index: u32 = 0, // highest completed segment suffix
    wal_path_buf: [256]u8 = undefined,
    wal_path_len: usize = 0,
    // single-writer lock file
    lock_path_buf: [256]u8 = undefined,
    lock_path_len: usize = 0,
    has_lock: bool = false,

    pub fn open(path: []const u8) !Wal {
        var file: std.fs.File = undefined;
        const cwd = std.fs.cwd();
        file = cwd.openFile(path, .{ .mode = .read_write }) catch |err| switch (err) {
            error.FileNotFound => blk: {
                _ = try cwd.createFile(path, .{});
                break :blk try cwd.openFile(path, .{ .mode = .read_write });
            },
            else => return err,
        };
        // Determine if header exists; write if empty
        const size = try file.getEndPos();
        var wal = Wal{ .file = file };
        // keep a stable copy of the wal path for rotation/segment ops
        wal.wal_path_len = @min(path.len, wal.wal_path_buf.len);
        @memcpy(wal.wal_path_buf[0..wal.wal_path_len], path[0..wal.wal_path_len]);
        // prepare lock path and acquire lock to enforce single-writer
        wal.lock_path_len = try computeLockPath(path, &wal.lock_path_buf);
        try acquireLock(&wal);
        // scan existing segments to compute highest index
        wal.segment_index = try wal.scanSegments();
        if (size == 0) {
            try wal.writeHeader();
        } else {
            wal.has_header = try wal.checkHeader();
        }
        // Establish a correct tail once on open (truncate trailing partials if any)
        wal.end_pos = try computeTail(&wal);
        // Initialize entries count in active segment based on end_pos
        if (wal.end_pos >= HEADER_SIZE) {
            const payload: u64 = wal.end_pos - HEADER_SIZE;
            const entry_size_u64: u64 = 8 + 1 + pool.constants.data.node_props_size + 4;
            wal.segment_entries = payload / entry_size_u64;
        } else {
            wal.segment_entries = 0;
        }
        return wal;
    }

    pub fn openReadOnly(path: []const u8) !Wal {
        // Open WAL without acquiring a lock and without any mutations.
        const cwd = std.fs.cwd();
        var file = cwd.openFile(path, .{ .mode = .read_only }) catch |e| switch (e) {
            error.FileNotFound => blk: {
                // If not present, create empty to allow reads; still safe as no lock is acquired.
                _ = try cwd.createFile(path, .{});
                break :blk try cwd.openFile(path, .{ .mode = .read_only });
            },
            else => return e,
        };
        var wal = Wal{ .file = file, .read_only = true };
        wal.wal_path_len = @min(path.len, wal.wal_path_buf.len);
        @memcpy(wal.wal_path_buf[0..wal.wal_path_len], path[0..wal.wal_path_len]);
        // Do not acquire lock in read-only mode.
        wal.segment_index = try wal.scanSegments();
        const size = try file.getEndPos();
        if (size == 0) {
            wal.has_header = false;
        } else {
            wal.has_header = try wal.checkHeader();
        }
        wal.end_pos = try computeTail(&wal);
        if (wal.end_pos >= HEADER_SIZE) {
            const payload: u64 = wal.end_pos - HEADER_SIZE;
            const entry_size_u64: u64 = 8 + 1 + pool.constants.data.node_props_size + 4;
            wal.segment_entries = payload / entry_size_u64;
        } else {
            wal.segment_entries = 0;
        }
        return wal;
    }

    pub fn append_insert_node(self: *Wal, node: pool.Node) !void {
        if (self.read_only) return error.AccessDenied;
        if (DEBUG_WAL) std.debug.print("append: start end_pos={} entries_written={} ops\n", .{ self.end_pos, self.entries_written });
        // Build entry buffer: [id(8) | kind(1) | props(N) | crc32(4)]
        const props_len = pool.constants.data.node_props_size;
        var fbs = std.io.fixedBufferStream(&self.entry_buf);
        const w = fbs.writer();
        try w.writeInt(u64, node.id, .little);
        try w.writeByte(node.kind);
        try w.writeAll(&node.props);
        const crc = std.hash.crc.Crc32.hash(self.entry_buf[0 .. 8 + 1 + props_len]);
        try w.writeInt(u32, crc, .little);
        // rotate if needed
        const entry_size: u64 = @as(u64, self.entry_buf.len);
        // Append at current in-memory tail; computeTail() was called on open/rotate
        var off: u64 = self.end_pos;
        // Check rotation against segment size limit
        if (off + entry_size > self.segment_size_limit) {
            try self.rotate();
            off = HEADER_SIZE;
        }
        if (DEBUG_WAL) std.debug.print("append: computed off={} before pwrite\n", .{off});
        self.file.pwriteAll(&self.entry_buf, off) catch |e| {
            self.recordIoError(e);
            return e;
        };
        // Ensure the OS-visible file size advances to include the newly written entry.
        // Some platforms' pwrite may not update the cached end position immediately.
        self.end_pos = off + entry_size;
        self.file.setEndPos(self.end_pos) catch |e| {
            self.recordIoError(e);
            return e;
        };
        // No need for additional debug of file size here; end_pos reflects our append
        // Recompute segment_entries from on-disk size for consistency
        if (self.end_pos >= HEADER_SIZE) {
            self.segment_entries = (self.end_pos - HEADER_SIZE) / entry_size;
        } else {
            self.segment_entries = 0;
        }
        // Batch fsyncs
        self.entries_since_sync += 1;
        self.entries_written += 1;
        self.bytes_written += self.entry_buf.len;
        if (DEBUG_WAL) std.debug.print("WAL append: entry_size={} new_end={} entries_written={} segment_entries={}\n", .{ self.entry_buf.len, self.end_pos, self.entries_written, self.segment_entries });
        if (self.entries_since_sync >= self.sync_every) {
            self.file.sync() catch |e| {
                self.recordIoError(e);
                return e;
            };
            self.entries_since_sync = 0;
        }
    }
    pub fn replay(self: *Wal, db: *pool.NodePool) !void {
        // First, replay completed segments in ascending order
        if (self.segment_index > 0) {
            var i: u32 = 1;
            while (i <= self.segment_index) : (i += 1) {
                var seg_path_buf: [256]u8 = undefined;
                const seg_path = try self.segmentPath(i, &seg_path_buf);
                var seg_file = std.fs.cwd().openFile(seg_path, .{ .mode = if (self.read_only) .read_only else .read_write }) catch |e| switch (e) {
                    error.FileNotFound => continue, // ignore gaps
                    else => return e,
                };
                defer seg_file.close();
                try self.replay_from_file(&seg_file, db);
            }
        }
        // Then replay the active WAL file (self.file) deterministically
        const entry_size: usize = 8 + 1 + pool.constants.data.node_props_size + 4; // id + kind + props + crc32
        var entry_count: usize = 0;
        var start_pos: u64 = 0;
        // header check via readAt
        {
            var hdr: [HEADER_SIZE]u8 = undefined;
            const ok = try readExactAt(&self.file, 0, &hdr);
            if (ok) {
                var rbs = std.io.fixedBufferStream(&hdr);
                const r = rbs.reader();
                const magic = try r.readInt(u32, .little);
                const version = try r.readInt(u16, .little);
                if (magic == WAL_MAGIC and version == WAL_VERSION) {
                    self.has_header = true;
                    start_pos = HEADER_SIZE;
                }
            }
        }
        const sz = try self.file.getEndPos();
        if (DEBUG_WAL) std.debug.print("WAL replay: sz={} start_pos={} entry_size={}\n", .{ sz, start_pos, entry_size });
        if (sz >= start_pos) {
            const total: u64 = sz - start_pos;
            const full: u64 = total / entry_size;
            var idx: u64 = 0;
            var corrupt = false;
            while (idx < full) : (idx += 1) {
                const off = start_pos + idx * entry_size;
                const ok = try readExactAt(&self.file, off, &self.entry_buf);
                if (!ok) {
                    corrupt = true;
                    break;
                }
                const crc_calc = std.hash.crc.Crc32.hash(self.entry_buf[0 .. 8 + 1 + pool.constants.data.node_props_size]);
                var fbs = std.io.fixedBufferStream(&self.entry_buf);
                var r = fbs.reader();
                const id = try r.readInt(u64, .little);
                const kind = try r.readByte();
                var props: [pool.constants.data.node_props_size]u8 = undefined;
                try r.readNoEof(&props);
                const crc_stored = try r.readInt(u32, .little);
                if (crc_calc != crc_stored) {
                    if (DEBUG_WAL) {
                        std.debug.print("CRC mismatch at off {}: calc={} stored={} first8={any}\n", .{ off, crc_calc, crc_stored, self.entry_buf[0..8] });
                    }
                    corrupt = true;
                    break;
                }
                const node = pool.Node{ .id = id, .kind = kind, .props = props };
                _ = try db.alloc(node);
                entry_count += 1;
                self.entries_replayed += 1;
            }
            if (!self.read_only and (corrupt or (total % entry_size != 0))) {
                const trunc_pos: u64 = start_pos + (entry_count * entry_size);
                if (DEBUG_WAL) std.debug.print("WAL replay: Detected trailing partial/corrupt entry. Truncating WAL to {} bytes.\n", .{trunc_pos});
                self.file.setEndPos(trunc_pos) catch |e| {
                    self.recordIoError(e);
                    return e;
                };
                self.file.sync() catch |e| {
                    self.recordIoError(e);
                    return e;
                };
                self.truncations += 1;
            }
        }
        if (DEBUG_WAL) std.debug.print("WAL replay: total entries loaded: {}\n", .{entry_count});
    }

    pub fn close(self: *Wal) void {
        if (self.closed) return;
        // Close file; OS will flush as needed. Avoid fsync() here to prevent platform-specific EBADF/INVAL panics.
        self.file.close();
        // release lock file
        if (self.has_lock) {
            const lock_path = self.lock_path_buf[0..self.lock_path_len];
            std.fs.cwd().deleteFile(lock_path) catch {};
            self.has_lock = false;
        }
        self.closed = true;
    }

    fn writeHeader(self: *Wal) !void {
        if (self.read_only) return error.AccessDenied;
        var buf: [HEADER_SIZE]u8 = undefined;
        var fbs = std.io.fixedBufferStream(&buf);
        const w = fbs.writer();
        try w.writeInt(u32, WAL_MAGIC, .little);
        try w.writeInt(u16, WAL_VERSION, .little);
        self.file.writeAll(&buf) catch |e| {
            self.recordIoError(e);
            return e;
        };
        fsyncFileStrict(&self.file) catch |e| {
            self.recordIoError(e);
            return e;
        };
        self.has_header = true;
        self.end_pos = HEADER_SIZE;
    }

    fn checkHeader(self: *Wal) !bool {
        try self.file.seekTo(0);
        var hdr: [HEADER_SIZE]u8 = undefined;
        const n = try self.file.read(&hdr);
        if (n < HEADER_SIZE) return false; // legacy or empty
        var rbs = std.io.fixedBufferStream(&hdr);
        const r = rbs.reader();
        const magic = try r.readInt(u32, .little);
        const version = try r.readInt(u16, .little);
        if (magic == WAL_MAGIC and version == WAL_VERSION) return true;
        return false;
    }

    pub fn truncate_to_header(self: *Wal) !void {
        if (self.read_only) return error.AccessDenied;
        if (DEBUG_WAL) std.debug.print("WAL: truncate_to_header has_header={} before_end={} before_seg_entries={}\n", .{ self.has_header, self.end_pos, self.segment_entries });
        if (self.has_header) {
            self.file.setEndPos(HEADER_SIZE) catch |e| {
                self.recordIoError(e);
                return e;
            };
            self.end_pos = HEADER_SIZE;
            self.segment_entries = 0;
        } else {
            self.file.setEndPos(0) catch |e| {
                self.recordIoError(e);
                return e;
            };
            self.end_pos = 0;
            self.segment_entries = 0;
        }
        self.file.sync() catch |e| {
            self.recordIoError(e);
            return e;
        };
        if (DEBUG_WAL) std.debug.print("WAL: truncate_to_header done end={} seg_entries={}\n", .{ self.end_pos, self.segment_entries });
    }

    pub fn flush(self: *Wal) !void {
        if (self.read_only) return error.AccessDenied;
        self.file.sync() catch |e| {
            self.recordIoError(e);
            return e;
        };
        self.entries_since_sync = 0;
    }

    pub const WalStats = struct {
        entries_written: u64,
        entries_replayed: u64,
        truncations: u32,
        bytes_written: u64,
    };

    pub fn getStats(self: *const Wal) WalStats {
        return WalStats{
            .entries_written = self.entries_written,
            .entries_replayed = self.entries_replayed,
            .truncations = self.truncations,
            .bytes_written = self.bytes_written,
        };
    }

    pub fn setSyncEvery(self: *Wal, n: u32) void {
        if (n == 0) return; // ignore invalid
        self.sync_every = n;
    }

    pub fn setSegmentSizeLimit(self: *Wal, n: u64) void {
        if (n >= 256) self.segment_size_limit = n;
    }

    pub const CheckResult = struct {
        ok: bool,
        entries: u64,
        truncated: bool,
        trunc_pos: u64,
    };

    /// Validate WAL header and each entry's CRC without loading into memory pools.
    /// If fix is true, truncates trailing partial/corrupt bytes to last good boundary.
    pub fn check(self: *Wal, fix: bool) !CheckResult {
        const entry_size: usize = 8 + 1 + pool.constants.data.node_props_size + 4;
        var buffer: [8 + 1 + pool.constants.data.node_props_size + 4]u8 = undefined;
        var entries: u64 = 0;
        var start_pos: u64 = 0;
        // header check via readAt
        {
            var hdr: [HEADER_SIZE]u8 = undefined;
            const ok = try readExactAt(&self.file, 0, &hdr);
            if (ok) {
                var rbs = std.io.fixedBufferStream(&hdr);
                const r = rbs.reader();
                const magic = try r.readInt(u32, .little);
                const version = try r.readInt(u16, .little);
                if (magic == WAL_MAGIC and version == WAL_VERSION) start_pos = HEADER_SIZE;
            }
        }
        const sz = try self.file.getEndPos();
        var trunc_pos: u64 = 0;
        if (sz >= start_pos) {
            const total: u64 = sz - start_pos;
            const full: u64 = total / entry_size;
            var idx: u64 = 0;
            while (idx < full) : (idx += 1) {
                const off = start_pos + idx * entry_size;
                const ok = try readExactAt(&self.file, off, &buffer);
                if (!ok) {
                    trunc_pos = off;
                    break;
                }
                const crc_calc = std.hash.crc.Crc32.hash(buffer[0 .. 8 + 1 + pool.constants.data.node_props_size]);
                var fbs = std.io.fixedBufferStream(&buffer);
                const r = fbs.reader();
                _ = try r.readInt(u64, .little);
                _ = try r.readByte();
                var props: [pool.constants.data.node_props_size]u8 = undefined;
                try r.readNoEof(&props);
                const crc_stored = try r.readInt(u32, .little);
                if (crc_stored != crc_calc) {
                    trunc_pos = off;
                    break;
                }
                entries += 1;
            }
            if (trunc_pos == 0 and (total % entry_size != 0)) {
                trunc_pos = start_pos + (full * entry_size);
            }
            if (trunc_pos != 0 and fix) {
                try self.file.setEndPos(trunc_pos);
                try fsyncFileStrict(&self.file);
            }
        }
        return CheckResult{
            .ok = (trunc_pos == 0),
            .entries = entries,
            .truncated = (trunc_pos != 0) and fix,
            .trunc_pos = trunc_pos,
        };
    }

    // --- internal helpers for rotation/segments ---
    fn splitDirAndBase(self: *const Wal) struct { dir: []const u8, base: []const u8 } {
        const path = self.wal_path_buf[0..self.wal_path_len];
        const idx_opt = std.mem.lastIndexOfScalar(u8, path, '/');
        if (idx_opt) |idx| {
            return .{ .dir = path[0..idx], .base = path[idx + 1 ..] };
        } else {
            return .{ .dir = ".", .base = path };
        }
    }

    fn segmentPath(self: *const Wal, index: u32, out_buf: *[256]u8) ![]const u8 {
        const parts = self.splitDirAndBase();
        // zero-pad index to 6 digits for lexicographic order
        var idx_buf: [6]u8 = undefined;
        const idx_str = fmtIndex(index, &idx_buf);
        return try std.fmt.bufPrint(out_buf, "{s}/{s}.{s}", .{ parts.dir, parts.base, idx_str });
    }

    fn fmtIndex(index: u32, buf: *[6]u8) []const u8 {
        // convert to decimal with zero pad width 6
        buf.* = [_]u8{'0'} ** 6;
        var tmp: u32 = index;
        var i: isize = 5;
        while (i >= 0) : (i -= 1) {
            const ui: usize = @intCast(i);
            const digit: u8 = @intCast(tmp % 10);
            buf.*[ui] = @as(u8, '0') + digit;
            tmp /= 10;
        }
        return buf.*[0..];
    }

    fn scanSegments(self: *Wal) !u32 {
        const parts = self.splitDirAndBase();
        var dir = try std.fs.cwd().openDir(parts.dir, .{ .iterate = true });
        defer dir.close();
        var max_idx: u32 = 0;
        var it = dir.iterate();
        while (try it.next()) |entry| {
            if (entry.kind != .file) continue;
            // match prefix base + '.'
            if (!std.mem.startsWith(u8, entry.name, parts.base)) continue;
            if (entry.name.len <= parts.base.len + 1) continue;
            if (entry.name[parts.base.len] != '.') continue;
            const suffix = entry.name[parts.base.len + 1 ..];
            // parse u32 index if numeric
            var ok = true;
            var idx_val: u32 = 0;
            for (suffix) |c| {
                if (c < '0' or c > '9') {
                    ok = false;
                    break;
                }
                const digit: u32 = @intCast(c - '0');
                idx_val = idx_val * 10 + digit;
            }
            if (ok and idx_val > max_idx) max_idx = idx_val;
        }
        return max_idx;
    }

    fn rotate(self: *Wal) !void {
        if (self.read_only) return error.AccessDenied;
        // Close current file, rename to .NNNNNN, fsync directory, create a fresh WAL with header
        const next_idx = self.segment_index + 1;
        var seg_path_buf: [256]u8 = undefined;
        const seg_path = try self.segmentPath(next_idx, &seg_path_buf);
        const wal_path = self.wal_path_buf[0..self.wal_path_len];
        // Ensure current WAL is durable before rotation
        fsyncFileStrict(&self.file) catch |e| {
            self.recordIoError(e);
            return e;
        };
        self.file.close();
        std.fs.cwd().rename(wal_path, seg_path) catch |e| {
            self.recordIoError(e);
            return e;
        };
        // Fsync directory to persist the rename
        fsyncDir(self.splitDirAndBase().dir) catch |e| {
            self.recordIoError(e);
            return e;
        };
        // open fresh wal and write header (allow reads for computeTail/replay)
        self.file = std.fs.cwd().createFile(wal_path, .{ .read = true }) catch |e| {
            self.recordIoError(e);
            return e;
        };
        self.has_header = false;
        self.writeHeader() catch |e| {
            self.recordIoError(e);
            return e;
        };
        // Ensure header and new file are durable; then fsync directory for new entry
        fsyncFileStrict(&self.file) catch |e| {
            self.recordIoError(e);
            return e;
        };
        fsyncDir(self.splitDirAndBase().dir) catch |e| {
            self.recordIoError(e);
            return e;
        };
        self.segment_index = next_idx;
        // reset entry batching so we don't skip an early fsync unnecessarily
        self.entries_since_sync = 0;
        // end_pos set by writeHeader
        self.segment_entries = 0;
    }

    fn replay_from_file(self: *Wal, file: *std.fs.File, db: *pool.NodePool) !void {
        const entry_size: usize = 8 + 1 + pool.constants.data.node_props_size + 4;
        // reuse self.entry_buf as buffer
        var entry_count: usize = 0;
        var start_pos: u64 = 0;
        // header check via readAt
        {
            var hdr: [HEADER_SIZE]u8 = undefined;
            const ok = try readExactAt(file, 0, &hdr);
            if (ok) {
                var rbs = std.io.fixedBufferStream(&hdr);
                const r = rbs.reader();
                const magic = try r.readInt(u32, .little);
                const version = try r.readInt(u16, .little);
                if (magic == WAL_MAGIC and version == WAL_VERSION) start_pos = HEADER_SIZE;
            }
        }
        const sz = try file.getEndPos();
        if (sz >= start_pos) {
            const total: u64 = sz - start_pos;
            const full: u64 = total / entry_size;
            var idx: u64 = 0;
            var trunc_due_crc: ?u64 = null;
            while (idx < full) : (idx += 1) {
                const off = start_pos + idx * entry_size;
                const ok = try readExactAt(file, off, &self.entry_buf);
                if (!ok) break;
                const crc_calc = std.hash.crc.Crc32.hash(self.entry_buf[0 .. 8 + 1 + pool.constants.data.node_props_size]);
                var fbs = std.io.fixedBufferStream(&self.entry_buf);
                var r = fbs.reader();
                const id = try r.readInt(u64, .little);
                const kind = try r.readByte();
                var props: [pool.constants.data.node_props_size]u8 = undefined;
                try r.readNoEof(&props);
                const crc_stored = try r.readInt(u32, .little);
                if (crc_calc != crc_stored) {
                    trunc_due_crc = off;
                    break;
                }
                const node = pool.Node{ .id = id, .kind = kind, .props = props };
                _ = try db.alloc(node);
                entry_count += 1;
                self.entries_replayed += 1;
            }
            // truncate trailing partial if any
            if (!self.read_only and (total % entry_size != 0)) {
                const trunc_pos: u64 = start_pos + (full * entry_size);
                file.setEndPos(trunc_pos) catch |e| {
                    self.recordIoError(e);
                    return e;
                };
                file.sync() catch |e| {
                    self.recordIoError(e);
                    return e;
                };
                self.truncations += 1;
            } else if (trunc_due_crc) |pos| {
                if (!self.read_only) {
                    // truncate at first bad entry boundary
                    file.setEndPos(pos) catch |e| {
                        self.recordIoError(e);
                        return e;
                    };
                    file.sync() catch |e| {
                        self.recordIoError(e);
                        return e;
                    };
                    self.truncations += 1;
                }
            }
        }
        if (DEBUG_WAL) std.debug.print("WAL replay (segment): total entries loaded: {}\n", .{entry_count});
    }

    pub fn delete_segments(self: *Wal) !u32 {
        if (self.read_only) return error.AccessDenied;
        // Delete all completed segments; return count removed
        const parts = self.splitDirAndBase();
        var dir = try std.fs.cwd().openDir(parts.dir, .{ .iterate = true });
        defer dir.close();
        var it = dir.iterate();
        var removed: u32 = 0;
        while (try it.next()) |entry| {
            if (entry.kind != .file) continue;
            if (!std.mem.startsWith(u8, entry.name, parts.base)) continue;
            if (entry.name.len <= parts.base.len + 1) continue;
            if (entry.name[parts.base.len] != '.') continue; // only .NNNNNN files
            dir.deleteFile(entry.name) catch |e| switch (e) {
                error.FileNotFound => continue,
                else => return e,
            };
            removed += 1;
        }
        // after deletion, reset segment index
        self.segment_index = 0;
        // Fsync directory to persist deletions
        std.posix.fsync(dir.fd) catch |e| {
            self.recordIoError(e);
            return e;
        };
        return removed;
    }

    /// Delete completed segments but keep the most recent `keep_last` segments.
    /// Returns the number of segments removed. If keep_last == 0, behaves like delete_segments().
    pub fn delete_segments_keep_last(self: *Wal, keep_last: u32) !u32 {
        if (self.read_only) return error.AccessDenied;
        if (keep_last == 0) return self.delete_segments();
        const parts = self.splitDirAndBase();
        var dir = try std.fs.cwd().openDir(parts.dir, .{ .iterate = true });
        defer dir.close();
        // First pass: find max index
        var it1 = dir.iterate();
        var max_idx: u32 = 0;
        while (try it1.next()) |entry| {
            if (entry.kind != .file) continue;
            if (!std.mem.startsWith(u8, entry.name, parts.base)) continue;
            if (entry.name.len <= parts.base.len + 1) continue;
            if (entry.name[parts.base.len] != '.') continue; // only .NNNNNN files
            const suffix = entry.name[parts.base.len + 1 ..];
            var ok = true;
            var idx_val: u32 = 0;
            for (suffix) |c| {
                if (c < '0' or c > '9') {
                    ok = false;
                    break;
                }
                const digit: u32 = @intCast(c - '0');
                idx_val = idx_val * 10 + digit;
            }
            if (ok and idx_val > max_idx) max_idx = idx_val;
        }
        if (max_idx == 0) return 0;
        const threshold: u32 = if (max_idx > keep_last) max_idx - keep_last else 0;
        // Second pass: delete indices <= threshold
        var removed: u32 = 0;
        var it2 = dir.iterate();
        while (try it2.next()) |entry| {
            if (entry.kind != .file) continue;
            if (!std.mem.startsWith(u8, entry.name, parts.base)) continue;
            if (entry.name.len <= parts.base.len + 1) continue;
            if (entry.name[parts.base.len] != '.') continue;
            const suffix = entry.name[parts.base.len + 1 ..];
            var ok = true;
            var idx_val: u32 = 0;
            for (suffix) |c| {
                if (c < '0' or c > '9') {
                    ok = false;
                    break;
                }
                const digit: u32 = @intCast(c - '0');
                idx_val = idx_val * 10 + digit;
            }
            if (!ok) continue;
            if (idx_val <= threshold) {
                dir.deleteFile(entry.name) catch |e| switch (e) {
                    error.FileNotFound => continue,
                    else => return e,
                };
                removed += 1;
            }
        }
        // segment_index remains max_idx
        self.segment_index = max_idx;
        std.posix.fsync(dir.fd) catch |e| {
            self.recordIoError(e);
            return e;
        };
        return removed;
    }

    // Sum the total number of complete entries across all segments and the active WAL.
    pub fn total_entries(self: *Wal) !u64 {
        const entry_size: u64 = 8 + 1 + pool.constants.data.node_props_size + 4;
        var total: u64 = 0;
        // segments
        if (self.segment_index > 0) {
            var i: u32 = 1;
            while (i <= self.segment_index) : (i += 1) {
                var seg_path_buf: [256]u8 = undefined;
                const seg_path = try self.segmentPath(i, &seg_path_buf);
                const f = std.fs.cwd().openFile(seg_path, .{ .mode = .read_only }) catch |e| switch (e) {
                    error.FileNotFound => continue,
                    else => return e,
                };
                defer f.close();
                const sz = try f.getEndPos();
                if (sz >= HEADER_SIZE) total += (sz - HEADER_SIZE) / entry_size;
            }
        }
        // active file (ensure tail is correct)
        const tail = try computeTail(self);
        if (tail >= HEADER_SIZE) total += (tail - HEADER_SIZE) / entry_size;
        return total;
    }

    // Replay starting from a global entry index (skip entries <= skip_lsn)
    pub fn replay_from_lsn(self: *Wal, db: *pool.NodePool, skip_lsn: u64) !void {
        const entry_size: u64 = 8 + 1 + pool.constants.data.node_props_size + 4;
        var remaining: u64 = skip_lsn;
        // First handle segments fully by skipping counts based on file size
        if (self.segment_index > 0) {
            var i: u32 = 1;
            while (i <= self.segment_index) : (i += 1) {
                var seg_path_buf: [256]u8 = undefined;
                const seg_path = try self.segmentPath(i, &seg_path_buf);
                var seg_file = std.fs.cwd().openFile(seg_path, .{ .mode = .read_write }) catch |e| switch (e) {
                    error.FileNotFound => continue,
                    else => return e,
                };
                defer seg_file.close();
                const sz = try seg_file.getEndPos();
                if (sz < HEADER_SIZE) continue;
                const seg_entries: u64 = (sz - HEADER_SIZE) / entry_size;
                if (remaining >= seg_entries) {
                    remaining -= seg_entries;
                    continue;
                }
                // Need to replay tail of this segment starting from remaining
                var buffer: [8 + 1 + pool.constants.data.node_props_size + 4]u8 = undefined;
                var idx: u64 = remaining;
                while (idx < seg_entries) : (idx += 1) {
                    const off = HEADER_SIZE + idx * entry_size;
                    const ok = try readExactAt(&seg_file, off, &buffer);
                    if (!ok) break;
                    const crc_calc = std.hash.crc.Crc32.hash(buffer[0 .. 8 + 1 + pool.constants.data.node_props_size]);
                    var fbs = std.io.fixedBufferStream(&buffer);
                    var r = fbs.reader();
                    const id = try r.readInt(u64, .little);
                    const kind = try r.readByte();
                    var props: [pool.constants.data.node_props_size]u8 = undefined;
                    try r.readNoEof(&props);
                    const crc_stored = try r.readInt(u32, .little);
                    if (crc_calc != crc_stored) break;
                    const node = pool.Node{ .id = id, .kind = kind, .props = props };
                    _ = try db.alloc(node);
                    self.entries_replayed += 1;
                }
                remaining = 0;
            }
        }
        // Now active WAL
        var start_pos: u64 = 0;
        // header check via readAt
        {
            var hdr: [HEADER_SIZE]u8 = undefined;
            const ok = try readExactAt(&self.file, 0, &hdr);
            if (ok) {
                var rbs = std.io.fixedBufferStream(&hdr);
                const r = rbs.reader();
                const magic = try r.readInt(u32, .little);
                const version = try r.readInt(u16, .little);
                if (magic == WAL_MAGIC and version == WAL_VERSION) {
                    self.has_header = true;
                    start_pos = HEADER_SIZE;
                }
            }
        }
        const tail = try computeTail(self);
        if (tail < start_pos) return;
        const total_active: u64 = (tail - start_pos) / entry_size;
        if (remaining >= total_active) return; // nothing to replay
        var idx2: u64 = remaining;
        while (idx2 < total_active) : (idx2 += 1) {
            const off = start_pos + idx2 * entry_size;
            const ok = try readExactAt(&self.file, off, &self.entry_buf);
            if (!ok) break;
            const crc_calc = std.hash.crc.Crc32.hash(self.entry_buf[0 .. 8 + 1 + pool.constants.data.node_props_size]);
            var fbs = std.io.fixedBufferStream(&self.entry_buf);
            var r = fbs.reader();
            const id = try r.readInt(u64, .little);
            const kind = try r.readByte();
            var props: [pool.constants.data.node_props_size]u8 = undefined;
            try r.readNoEof(&props);
            const crc_stored = try r.readInt(u32, .little);
            if (crc_calc != crc_stored) break;
            const node = pool.Node{ .id = id, .kind = kind, .props = props };
            _ = try db.alloc(node);
            self.entries_replayed += 1;
        }
    }

    // --- health reporting ---
    pub const WalHealth = struct {
        healthy: bool,
        io_error_count: u32,
        last_error: ?anyerror,
        closed: bool,
        read_only: bool,
        has_header: bool,
        end_pos: u64,
        segment_entries: u64,
        segment_index: u32,
    };

    fn recordIoError(self: *Wal, e: anyerror) void {
        self.last_error = e;
        self.io_error_count +%= 1;
    }

    pub fn getHealth(self: *const Wal) WalHealth {
        const unhealthy = self.closed or (self.io_error_count != 0) or (self.last_error != null);
        return WalHealth{
            .healthy = !unhealthy,
            .io_error_count = self.io_error_count,
            .last_error = self.last_error,
            .closed = self.closed,
            .read_only = self.read_only,
            .has_header = self.has_header,
            .end_pos = self.end_pos,
            .segment_entries = self.segment_entries,
            .segment_index = self.segment_index,
        };
    }
};

// Read exactly buf.len bytes from file starting at absolute offset.
// Returns true if full buffer was read, false if EOF encountered before full read.
fn readExactAt(file: *std.fs.File, off: u64, buf: []u8) !bool {
    try file.seekTo(off);
    var total: usize = 0;
    while (total < buf.len) {
        const n = try file.read(buf[total..]);
        if (n == 0) return false; // EOF before complete
        total += n;
    }
    return true;
}

// Determine the correct append offset by verifying the header and each full entry.
// If trailing partial/corrupt data exists, truncate and return the last good boundary.
fn computeTail(self: *Wal) !u64 {
    const entry_size: usize = 8 + 1 + pool.constants.data.node_props_size + 4;
    const sz = try self.file.getEndPos();
    if (DEBUG_WAL) std.debug.print("computeTail: file_sz={} entry_size={}\n", .{ sz, entry_size });
    if (sz < HEADER_SIZE) return HEADER_SIZE;
    // Validate header
    var hdr: [HEADER_SIZE]u8 = undefined;
    const have = try readExactAt(&self.file, 0, &hdr);
    if (!have) return HEADER_SIZE;
    var rbs = std.io.fixedBufferStream(&hdr);
    const r = rbs.reader();
    const magic = try r.readInt(u32, .little);
    const version = try r.readInt(u16, .little);
    if (!(magic == WAL_MAGIC and version == WAL_VERSION)) return 0; // invalid/legacy
    var off: u64 = HEADER_SIZE;
    var buffer: [8 + 1 + pool.constants.data.node_props_size + 4]u8 = undefined;
    while (off + entry_size <= sz) {
        const ok = try readExactAt(&self.file, off, &buffer);
        if (!ok) break;
        const crc_calc = std.hash.crc.Crc32.hash(buffer[0 .. 8 + 1 + pool.constants.data.node_props_size]);
        var fbs = std.io.fixedBufferStream(&buffer);
        var rr = fbs.reader();
        _ = try rr.readInt(u64, .little);
        _ = try rr.readByte();
        var props: [pool.constants.data.node_props_size]u8 = undefined;
        try rr.readNoEof(&props);
        const crc_stored = try rr.readInt(u32, .little);
        if (crc_stored != crc_calc) break;
        off += entry_size;
    }
    if (off != sz) {
        if (!self.read_only) {
            self.file.setEndPos(off) catch |e| {
                self.recordIoError(e);
                return e;
            };
            self.file.sync() catch |e| {
                self.recordIoError(e);
                return e;
            };
            self.truncations += 1;
        }
    }
    return off;
}

// Fsync the directory containing the WAL path
fn fsyncDir(path: []const u8) !void {
    var dir = try std.fs.cwd().openDir(path, .{});
    defer dir.close();
    if (builtin.os.tag == .macos) {
        // Try F_FULLFSYNC on directories where supported; otherwise fallback
        _ = std.posix.fcntl(dir.fd, std.posix.F.FULLFSYNC, 1) catch try std.posix.fsync(dir.fd);
    } else {
        try std.posix.fsync(dir.fd);
    }
}

// Strong fsync for files: F_FULLFSYNC on macOS, fallback to fsync elsewhere
fn fsyncFileStrict(f: *std.fs.File) !void {
    if (builtin.os.tag == .macos) {
        _ = std.posix.fcntl(f.handle, std.posix.F.FULLFSYNC, 1) catch try f.sync();
    } else {
        try f.sync();
    }
}

// --- lock file helpers ---
fn computeLockPath(wal_path: []const u8, out: *[256]u8) !usize {
    // Derive lock file as <dir>/<base>.lock
    const idx_opt = std.mem.lastIndexOfScalar(u8, wal_path, '/');
    if (idx_opt) |idx| {
        const dir = wal_path[0..idx];
        const base = wal_path[idx + 1 .. wal_path.len];
        const s = try std.fmt.bufPrint(out, "{s}/{s}.lock", .{ dir, base });
        return s.len;
    } else {
        const s2 = try std.fmt.bufPrint(out, "{s}.lock", .{wal_path});
        return s2.len;
    }
}

fn acquireLock(self: *Wal) !void {
    const lock_path = self.lock_path_buf[0..self.lock_path_len];
    // Try to create exclusively; if it already exists, treat as AlreadyLocked
    var f = std.fs.cwd().createFile(lock_path, .{ .read = true, .exclusive = true }) catch |e| switch (e) {
        error.PathAlreadyExists => return error.AccessDenied,
        else => return e,
    };
    defer f.close();
    // best-effort: write marker for diagnostics (no PID dependency)
    var w = f.writer();
    _ = w.writeAll("locked\n") catch {};
    _ = f.sync() catch {};
    self.has_lock = true;
}
