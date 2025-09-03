// NenDB Custom I/O Module
// Zero-dependency, static-memory, inline functions
// Inspired by Super-ZIG/io but completely self-contained

const std = @import("std");

// ASCII utilities
pub const ASCII = struct {
    // Character classification
    pub inline fn isWhitespace(c: u8) bool {
        return switch (c) {
            ' ', '\t', '\n', '\r', '\x0C', '\x0B' => true,
            else => false,
        };
    }

    pub inline fn isDigit(c: u8) bool {
        return c >= '0' and c <= '9';
    }

    pub inline fn isAlpha(c: u8) bool {
        return (c >= 'a' and c <= 'z') or (c >= 'A' and c <= 'Z');
    }

    pub inline fn isAlphanumeric(c: u8) bool {
        return isDigit(c) or isAlpha(c);
    }

    pub inline fn isLower(c: u8) bool {
        return c >= 'a' and c <= 'z';
    }

    pub inline fn isUpper(c: u8) bool {
        return c >= 'A' and c <= 'Z';
    }

    // Case conversion
    pub inline fn toLower(c: u8) u8 {
        return if (isUpper(c)) c + 32 else c;
    }

    pub inline fn toUpper(c: u8) u8 {
        return if (isLower(c)) c - 32 else c;
    }

    // String utilities
    pub inline fn trimLeft(s: []const u8) []const u8 {
        var i: usize = 0;
        while (i < s.len and isWhitespace(s[i])) : (i += 1) {}
        return s[i..];
    }

    pub inline fn trimRight(s: []const u8) []const u8 {
        var i: usize = s.len;
        while (i > 0 and isWhitespace(s[i - 1])) : (i -= 1) {}
        return s[0..i];
    }

    pub inline fn trim(s: []const u8) []const u8 {
        return trimRight(trimLeft(s));
    }

    pub inline fn startsWith(s: []const u8, prefix: []const u8) bool {
        if (s.len < prefix.len) return false;
        return std.mem.eql(u8, s[0..prefix.len], prefix);
    }

    pub inline fn endsWith(s: []const u8, suffix: []const u8) bool {
        if (s.len < suffix.len) return false;
        return std.mem.eql(u8, s[s.len - suffix.len ..], suffix);
    }
};

// UTF-8 utilities
pub const UTF8 = struct {
    pub inline fn isValidSequence(bytes: []const u8) bool {
        if (bytes.len == 0) return false;
        const first = bytes[0];
        if (first < 0x80) return bytes.len == 1;
        if (first < 0xC2) return false;
        if (first < 0xE0) return bytes.len == 2 and (bytes[1] & 0xC0) == 0x80;
        if (first < 0xF0) return bytes.len == 3 and (bytes[1] & 0xC0) == 0x80 and (bytes[2] & 0xC0) == 0x80;
        if (first < 0xF5) return bytes.len == 4 and (bytes[1] & 0xC0) == 0x80 and (bytes[2] & 0xC0) == 0x80 and (bytes[3] & 0xC0) == 0x80;
        return false;
    }

    pub inline fn decode(bytes: []const u8) !u21 {
        if (!isValidSequence(bytes)) return error.InvalidUtf8;
        if (bytes[0] < 0x80) return bytes[0];
        if (bytes[0] < 0xE0) {
            return @as(u21, bytes[0] & 0x1F) << 6 | @as(u21, bytes[1] & 0x3F);
        }
        if (bytes[0] < 0xF0) {
            return @as(u21, bytes[0] & 0x0F) << 12 | @as(u21, bytes[1] & 0x3F) << 6 | @as(u21, bytes[2] & 0x3F);
        }
        return @as(u21, bytes[0] & 0x07) << 18 | @as(u21, bytes[1] & 0x3F) << 12 | @as(u21, bytes[2] & 0x3F) << 6 | @as(u21, bytes[3] & 0x3F);
    }
};

// Static string buffer
pub const String = struct {
    pub const StaticBuffer = struct {
        data: [1024]u8,
        len: usize,

        pub inline fn init() StaticBuffer {
            return .{ .data = undefined, .len = 0 };
        }

        pub inline fn reset(self: *StaticBuffer) void {
            self.len = 0;
        }

        pub inline fn append(self: *StaticBuffer, s: []const u8) !void {
            if (self.len + s.len > self.data.len) return error.BufferFull;
            std.mem.copy(u8, self.data[self.len..][0..s.len], s);
            self.len += s.len;
        }

        pub inline fn slice(self: StaticBuffer) []const u8 {
            return self.data[0..self.len];
        }

        pub inline fn clear(self: *StaticBuffer) void {
            self.len = 0;
        }
    };

    pub inline fn join(separator: []const u8, parts: []const []const u8) !StaticBuffer {
        var buf = StaticBuffer.init();
        for (parts, 0..) |part, i| {
            if (i > 0) try buf.append(separator);
            try buf.append(part);
        }
        return buf;
    }
};

// Terminal utilities
pub const Terminal = struct {
    pub const Colors = struct {
        pub const reset = "\x1b[0m";
        pub const red = "\x1b[31m";
        pub const green = "\x1b[32m";
        pub const yellow = "\x1b[33m";
        pub const blue = "\x1b[34m";
        pub const magenta = "\x1b[35m";
        pub const cyan = "\x1b[36m";
        pub const white = "\x1b[37m";
        pub const bold = "\x1b[1m";
        pub const dim = "\x1b[2m";
        pub const underline = "\x1b[4m";
    };

    pub inline fn printColor(color: []const u8, comptime fmt: []const u8, args: anytype) !void {
        const stderr_file = std.fs.File{ .handle = 2 };

        // Format the message first
        var msg_buffer: [1024]u8 = undefined;
        const formatted = try std.fmt.bufPrint(&msg_buffer, fmt, args);

        try stderr_file.writeAll(color);
        try stderr_file.writeAll(formatted);
        try stderr_file.writeAll(Colors.reset);
    }

    pub inline fn successln(comptime fmt: []const u8, args: anytype) !void {
        try printColor(Colors.green, fmt ++ "\n", args);
    }

    pub inline fn warningln(comptime fmt: []const u8, args: anytype) !void {
        try printColor(Colors.yellow, fmt ++ "\n", args);
    }

    pub inline fn errorln(comptime fmt: []const u8, args: anytype) !void {
        try printColor(Colors.red, fmt ++ "\n", args);
    }

    pub inline fn infoln(comptime fmt: []const u8, args: anytype) !void {
        try printColor(Colors.blue, fmt ++ "\n", args);
    }

    pub inline fn printRed(comptime fmt: []const u8, args: anytype) !void {
        try printColor(Colors.red, fmt, args);
    }

    pub inline fn printGreen(comptime fmt: []const u8, args: anytype) !void {
        try printColor(Colors.green, fmt, args);
    }

    pub inline fn printYellow(comptime fmt: []const u8, args: anytype) !void {
        try printColor(Colors.yellow, fmt, args);
    }

    pub inline fn printBlue(comptime fmt: []const u8, args: anytype) !void {
        try printColor(Colors.blue, fmt, args);
    }

    pub inline fn println(comptime fmt: []const u8, args: anytype) !void {
        try printColor(Colors.white, fmt, args);
    }

    pub inline fn success(comptime fmt: []const u8, args: anytype) !void {
        try printColor(Colors.green, fmt, args);
    }

    pub inline fn printErrorToStderr(comptime fmt: []const u8, args: anytype) !void {
        try printColor(Colors.red, fmt, args);
    }

    pub inline fn printErrorLineToStderr(comptime fmt: []const u8, args: anytype) !void {
        try printErrorToStderr(fmt ++ "\n", args);
    }

    // Terminal size detection
    pub inline fn getTerminalSize() !struct { width: u32, height: u32 } {
        // Simple fallback for now
        return .{ .width = 80, .height = 24 };
    }

    // Progress bar
    pub const ProgressBar = struct {
        current: u32,
        total: u32,
        width: u32,

        pub inline fn init(total: u32) !ProgressBar {
            const size = try getTerminalSize();
            return .{
                .current = 0,
                .total = total,
                .width = size.width - 10,
            };
        }

        pub inline fn update(self: *ProgressBar, progress: u32) !void {
            self.current = @min(progress, self.total);
            const percentage = @as(f32, @floatFromInt(self.current)) / @as(f32, @floatFromInt(self.total));
            const filled = @as(u32, @intFromFloat(percentage * @as(f32, @floatFromInt(self.width))));

            const stderr = std.fs.File.openHandle(2).writer();
            try stderr.print("\r[", .{});
            var i: u32 = 0;
            while (i < self.width) : (i += 1) {
                if (i < filled) {
                    try stderr.print("=", .{});
                } else if (i == filled) {
                    try stderr.print(">", .{});
                } else {
                    try stderr.print(" ", .{});
                }
            }
            try stderr.print("] {d}%", .{percentage * 100});
        }

        pub inline fn finish(self: *ProgressBar) !void {
            _ = self;
            const stderr = std.fs.File.openHandle(2).writer();
            try stderr.print("\n", .{});
        }
    };
};

// File utilities with static buffers
pub const File = struct {
    pub inline fn openStatic(path: []const u8, flags: std.fs.File.OpenFlags) !std.fs.File {
        return try std.fs.cwd().openFile(path, flags);
    }

    pub inline fn createStatic(path: []const u8, flags: std.fs.File.CreateFlags) !std.fs.File {
        return try std.fs.cwd().createFile(path, flags);
    }

    pub inline fn readToEndStatic(file: std.fs.File, allocator: std.mem.Allocator) ![]u8 {
        return file.readToEndAlloc(allocator, std.math.maxInt(usize));
    }

    pub inline fn writeStatic(file: std.fs.File, data: []const u8) !void {
        try file.writeAll(data);
    }

    pub inline fn exists(path: []const u8) bool {
        std.fs.cwd().access(path, .{}) catch return false;
        return true;
    }

    pub inline fn remove(path: []const u8) !void {
        try std.fs.cwd().deleteFile(path);
    }

    pub inline fn rename(old_path: []const u8, new_path: []const u8) !void {
        try std.fs.cwd().rename(old_path, new_path);
    }

    pub inline fn copy(src_path: []const u8, dst_path: []const u8) !void {
        const src = try openStatic(src_path, .{});
        defer src.close();
        const dst = try createStatic(dst_path, .{});
        defer dst.close();
        try src.copy(dst);
    }
};

// Time utilities with static formatting
pub const Time = struct {
    pub inline fn formatStatic(time: std.time.epoch.EpochSeconds, comptime fmt: []const u8) !String.StaticBuffer {
        var buf = String.StaticBuffer.init();
        const epoch_day = time.getDaySeconds();
        const seconds_since_midnight = epoch_day.getDaySeconds();
        const hours = @divFloor(seconds_since_midnight.getTotalSeconds(), 3600);
        const minutes = @divFloor(@mod(seconds_since_midnight.getTotalSeconds(), 3600), 60);
        const seconds = @mod(seconds_since_midnight.getTotalSeconds(), 60);

        _ = fmt; // TODO: Implement format parsing
        try buf.append("2024-01-01 "); // Simplified for now
        if (hours < 10) try buf.append("0");
        try buf.append(try std.fmt.bufPrint(&buf.data[buf.len..][0..10], "{d}", .{hours}));
        try buf.append(":");
        if (minutes < 10) try buf.append("0");
        try buf.append(try std.fmt.bufPrint(&buf.data[buf.len..][0..10], "{d}", .{minutes}));
        try buf.append(":");
        if (seconds < 10) try buf.append("0");
        try buf.append(try std.fmt.bufPrint(&buf.data[buf.len..][0..10], "{d}", .{seconds}));

        return buf;
    }

    pub inline fn now() std.time.epoch.EpochSeconds {
        return std.time.epoch.EpochSeconds{ .secs = @intFromFloat(@as(f64, @floatFromInt(std.time.milliTimestamp())) / 1000.0) };
    }

    pub inline fn sleep(seconds: u64) void {
        const nanos = seconds * std.time.ns_per_s;
        std.time.sleep(nanos);
    }
};

// CLI utilities with static buffers
pub const CLI = struct {
    pub inline fn promptStatic(comptime message: []const u8) !String.StaticBuffer {
        const stdin = std.io.getStdIn().reader();
        const stderr = std.fs.File.openHandle(2).writer();
        try stderr.print("{s}: ", .{message});

        var buf = String.StaticBuffer.init();
        var byte: [1]u8 = undefined;
        while (stdin.read(&byte)) {
            if (byte[0] == '\n') break;
            try buf.append(&byte);
        } else |err| switch (err) {
            error.EndOfStream => {},
            else => return err,
        }

        return buf;
    }

    pub inline fn confirm(comptime message: []const u8) !bool {
        const stderr = std.fs.File.openHandle(2).writer();
        try stderr.print("{s} (y/N): ", .{message});

        const stdin = std.io.getStdIn().reader();
        var byte: [1]u8 = undefined;
        _ = stdin.read(&byte) catch return false;

        return byte[0] == 'y' or byte[0] == 'Y';
    }

    pub inline fn readLine() !String.StaticBuffer {
        const stdin = std.io.getStdIn().reader();
        var buf = String.StaticBuffer.init();
        var byte: [1]u8 = undefined;

        while (stdin.read(&byte)) {
            if (byte[0] == '\n') break;
            try buf.append(&byte);
        } else |err| switch (err) {
            error.EndOfStream => {},
            else => return err,
        }

        return buf;
    }

    pub inline fn printUsage(comptime usage: []const u8) !void {
        try Terminal.printBlue("Usage: {s}\n", .{usage});
    }

    pub inline fn printHelp(help_text: []const u8) !void {
        try Terminal.printBlue("{s}\n", .{help_text});
    }
};

// Network utilities with static buffers
pub const Network = struct {
    pub const Address = struct {
        host: [256]u8,
        port: u16,
        host_len: usize,

        pub inline fn init(host_str: []const u8, port_num: u16) !Address {
            if (host_str.len >= 256) return error.HostTooLong;
            var addr = Address{
                .host = undefined,
                .port = port_num,
                .host_len = host_str.len,
            };
            std.mem.copy(u8, &addr.host, host_str);
            return addr;
        }

        pub inline fn slice(self: Address) []const u8 {
            return self.host[0..self.host_len];
        }

        pub inline fn toString(self: Address) !String.StaticBuffer {
            var buf = String.StaticBuffer.init();
            try buf.append(self.slice());
            try buf.append(":");
            try buf.append(try std.fmt.bufPrint(&buf.data[buf.len..][0..10], "{d}", .{self.port}));
            return buf;
        }
    };

    pub inline fn connect(addr: Address) !std.net.Stream {
        return try std.net.tcpConnectToAddress(.{ .port = addr.port });
    }

    pub inline fn listen(addr: Address) !std.net.StreamServer {
        return try std.net.StreamServer.init(.{ .port = addr.port });
    }

    pub inline fn resolveHost(host: []const u8) !std.net.Address {
        return try std.net.Address.parseIp(host, 0);
    }
};

// Error utilities
pub const Error = struct {
    pub inline fn printError(err: anyerror, comptime context: []const u8) !void {
        try Terminal.errorln("{s}: {s}", .{ context, @errorName(err) });
    }

    pub inline fn printErrorWithDetails(err: anyerror, comptime context: []const u8, details: []const u8) !void {
        try Terminal.errorln("{s}: {s} - {s}", .{ context, @errorName(err), details });
    }
};

// Logging utilities
pub const Log = struct {
    pub const Level = enum {
        debug,
        info,
        warn,
        err,
    };

    pub inline fn log(level: Level, comptime fmt: []const u8, args: anytype) !void {
        const stderr = std.fs.File.openHandle(2).writer();
        const timestamp = try Time.formatStatic(Time.now(), "YYYY-MM-DD HH:mm:ss");

        switch (level) {
            .debug => try Terminal.printBlue("[DEBUG] ", .{}),
            .info => try Terminal.printGreen("[INFO] ", .{}),
            .warn => try Terminal.printYellow("[WARN] ", .{}),
            .err => try Terminal.printRed("[ERROR] ", .{}),
        }

        try stderr.print("{s} ", .{timestamp.slice()});
        try stderr.print(fmt ++ "\n", args);
    }

    pub inline fn debug(comptime fmt: []const u8, args: anytype) !void {
        try log(.debug, fmt, args);
    }

    pub inline fn info(comptime fmt: []const u8, args: anytype) !void {
        try log(.info, fmt, args);
    }

    pub inline fn warn(comptime fmt: []const u8, args: anytype) !void {
        try log(.warn, fmt, args);
    }

    pub inline fn err(comptime fmt: []const u8, args: anytype) !void {
        try log(.err, fmt, args);
    }
};
