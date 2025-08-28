// NenDB Static I/O Module
// Inspired by Super-ZIG/io - Zero dependencies, static memory, inline functions
// Production-ready with maximum performance

const std = @import("std");

// ╔══════════════════════════════════════ CORE ══════════════════════════════════════╗

pub const Terminal = struct {
    pub const Color = enum {
        black,
        red,
        green,
        yellow,
        blue,
        magenta,
        cyan,
        white,
        bright_black,
        bright_red,
        bright_green,
        bright_yellow,
        bright_blue,
        bright_magenta,
        bright_cyan,
        bright_white,
        reset,
    };

    pub const Style = enum {
        bold,
        dim,
        italic,
        underline,
        blink,
        reverse,
        hidden,
        strikethrough,
        reset,
    };

    pub inline fn color(color_name: Color) []const u8 {
        return switch (color_name) {
            .black => "\x1b[30m",
            .red => "\x1b[31m",
            .green => "\x1b[32m",
            .yellow => "\x1b[33m",
            .blue => "\x1b[34m",
            .magenta => "\x1b[35m",
            .cyan => "\x1b[36m",
            .white => "\x1b[37m",
            .bright_black => "\x1b[90m",
            .bright_red => "\x1b[91m",
            .bright_green => "\x1b[92m",
            .bright_yellow => "\x1b[93m",
            .bright_blue => "\x1b[94m",
            .bright_magenta => "\x1b[95m",
            .bright_cyan => "\x1b[96m",
            .bright_white => "\x1b[97m",
            .reset => "\x1b[0m",
        };
    }

    pub inline fn style(style_name: Style) []const u8 {
        return switch (style_name) {
            .bold => "\x1b[1m",
            .dim => "\x1b[2m",
            .italic => "\x1b[3m",
            .underline => "\x1b[4m",
            .blink => "\x1b[5m",
            .reverse => "\x1b[7m",
            .hidden => "\x1b[8m",
            .strikethrough => "\x1b[9m",
            .reset => "\x1b[0m",
        };
    }

    pub inline fn print(comptime format: []const u8, args: anytype) void {
        const stdout = std.io.getStdOut();
        stdout.writer().print(format, args) catch {};
    }

    pub inline fn println(comptime format: []const u8, args: anytype) void {
        print(format, args);
        print("\n", .{});
    }

    pub inline fn printErrorToStderr(comptime format: []const u8, args: anytype) void {
        const stderr = std.io.getStdErr();
        stderr.writer().print(format, args) catch {};
    }

    pub inline fn printErrorLineToStderr(comptime format: []const u8, args: anytype) void {
        printErrorToStderr(format, args);
        printErrorToStderr("\n", .{});
    }

    pub inline fn success(comptime format: []const u8, args: anytype) void {
        print(color(.green) ++ format ++ color(.reset), args);
    }

    pub inline fn warning(comptime format: []const u8, args: anytype) void {
        print(color(.yellow) ++ format ++ color(.reset), args);
    }


    pub inline fn printRed(comptime format: []const u8, args: anytype) void {
        print(color(.red) ++ format ++ color(.reset), args);
    }

    pub inline fn info(comptime format: []const u8, args: anytype) void {
        print(color(.blue) ++ format ++ color(.reset), args);
    }

    pub inline fn successln(comptime format: []const u8, args: anytype) void {
        success(format, args);
        println("", .{});
    }

    pub inline fn warningln(comptime format: []const u8, args: anytype) void {
        warning(format, args);
        println("", .{});
    }

    pub inline fn printErrorLine(comptime format: []const u8, args: anytype) void {
        printRed(format, args);
        println("", .{});
    }

    pub inline fn infoln(comptime format: []const u8, args: anytype) void {
        info(format, args);
        println("", .{});
    }
};

// ╔══════════════════════════════════════ STRING UTILITIES ═══════════════════════════╗

pub const String = struct {
    // Static buffer for string operations (inspired by Super-ZIG/io)
    pub const StaticBuffer = struct {
        data: [1024]u8,
        len: usize,

        pub inline fn init() StaticBuffer {
            return .{ .data = [_]u8{0} ** 1024, .len = 0 };
        }

        pub inline fn write(self: *StaticBuffer, input: []const u8) !void {
            if (self.len + input.len > self.data.len) {
                return error.BufferTooSmall;
            }
            @memcpy(self.data[self.len..][0..input.len], input);
            self.len += input.len;
        }

        pub inline fn writeByte(self: *StaticBuffer, byte: u8) !void {
            if (self.len >= self.data.len) {
                return error.BufferTooSmall;
            }
            self.data[self.len] = byte;
            self.len += 1;
        }

        pub inline fn items(self: *const StaticBuffer) []const u8 {
            return self.data[0..self.len];
        }

        pub inline fn clear(self: *StaticBuffer) void {
            self.len = 0;
        }

        pub inline fn reset(self: *StaticBuffer) void {
            self.len = 0;
            @memset(self.data, 0);
        }
    };

    // Enhanced string utilities (inspired by Super-ZIG/io patterns)
    pub inline fn trim(s: []const u8) []const u8 {
        var start: usize = 0;
        var end: usize = s.len;

        // Trim leading whitespace
        while (start < end and ASCII.isWhitespace(s[start])) {
            start += 1;
        }

        // Trim trailing whitespace
        while (end > start and ASCII.isWhitespace(s[end - 1])) {
            end -= 1;
        }

        return s[start..end];
    }

    pub inline fn trimLeft(s: []const u8) []const u8 {
        var start: usize = 0;
        while (start < s.len and ASCII.isWhitespace(s[start])) {
            start += 1;
        }
        return s[start..];
    }

    pub inline fn trimRight(s: []const u8) []const u8 {
        var end: usize = s.len;
        while (end > 0 and ASCII.isWhitespace(s[end - 1])) {
            end -= 1;
        }
        return s[0..end];
    }

    pub inline fn join(static_buffer: []u8, strings: []const []const u8, separator: []const u8) ![]u8 {
        var len: usize = 0;
        for (strings, 0..) |str, i| {
            if (i > 0) {
                if (len + separator.len > static_buffer.len) return error.BufferTooSmall;
                @memcpy(static_buffer[len..][0..separator.len], separator);
                len += separator.len;
            }
            if (len + str.len > static_buffer.len) return error.BufferTooSmall;
            @memcpy(static_buffer[len..][0..str.len], str);
            len += str.len;
        }
        return static_buffer[0..len];
    }

    pub inline fn startsWith(s: []const u8, prefix: []const u8) bool {
        return s.len >= prefix.len and std.mem.eql(u8, s[0..prefix.len], prefix);
    }

    pub inline fn endsWith(s: []const u8, suffix: []const u8) bool {
        return s.len >= suffix.len and std.mem.eql(u8, s[s.len - suffix.len..], suffix);
    }

    pub inline fn contains(s: []const u8, needle: []const u8) bool {
        return std.mem.indexOf(u8, s, needle) != null;
    }

    pub inline fn toLower(s: []u8) void {
        for (s) |*c| {
            c.* = ASCII.toLower(c.*);
        }
    }

    pub inline fn toUpper(s: []u8) void {
        for (s) |*c| {
            c.* = ASCII.toUpper(c.*);
        }
    }
};

// ╔══════════════════════════════════════ ASCII UTILITIES ═══════════════════════════╗

pub const ASCII = struct {
    pub inline fn toUpper(c: u8) u8 {
        const mask = @as(u8, @intFromBool(isLower(c))) << 5;
        return c ^ mask;
    }

    pub inline fn toLower(c: u8) u8 {
        const mask = @as(u8, @intFromBool(isUpper(c))) << 5;
        return c | mask;
    }

    pub inline fn isUpper(c: u8) bool {
        return switch (c) {
            'A'...'Z' => true,
            else => false,
        };
    }

    pub inline fn isLower(c: u8) bool {
        return switch (c) {
            'a'...'z' => true,
            else => false,
        };
    }

    pub inline fn isAlphabetic(c: u8) bool {
        return switch (c) {
            'A'...'Z', 'a'...'z' => true,
            else => false,
        };
    }

    pub inline fn isDigit(c: u8) bool {
        return switch (c) {
            '0'...'9' => true,
            else => false,
        };
    }

    pub inline fn isAlphanumeric(c: u8) bool {
        return switch (c) {
            'A'...'Z', 'a'...'z', '0'...'9' => true,
            else => false,
        };
    }

    pub inline fn isHex(c: u8) bool {
        return switch (c) {
            '0'...'9', 'A'...'F', 'a'...'f' => true,
            else => false,
        };
    }

    pub inline fn isWhitespace(c: u8) bool {
        return switch (c) {
            ' ', '\t', '\n', '\r' => true,
            else => false,
        };
    }

    pub inline fn isPrintable(c: u8) bool {
        return switch (c) {
            ' '...'~' => true,
            else => false,
        };
    }

    pub inline fn isControl(c: u8) bool {
        return (c <= 0x1F) or (c == 0x7F);
    }
};

// ╔══════════════════════════════════════ UTF-8 UTILITIES ═══════════════════════════╗

pub const UTF8 = struct {
    pub inline fn encode(cp: u21, out: []u8) u3 {
        const length = getCodepointLength(cp);
        switch (length) {
            1 => {
                out[0] = @truncate(cp);
            },
            2 => {
                out[0] = @truncate(0xC0 | (cp >> 6));
                out[1] = @truncate(0x80 | (cp & 0x3F));
            },
            3 => {
                out[0] = @truncate(0xE0 | (cp >> 12));
                out[1] = @truncate(0x80 | ((cp >> 6) & 0x3F));
                out[2] = @truncate(0x80 | (cp & 0x3F));
            },
            else => {
                out[0] = @truncate(0xF0 | (cp >> 18));
                out[1] = @truncate(0x80 | ((cp >> 12) & 0x3F));
                out[2] = @truncate(0x80 | ((cp >> 6) & 0x3F));
                out[3] = @truncate(0x80 | (cp & 0x3F));
            }
        }
        return length;
    }

    pub inline fn decode(slice: []const u8) u21 {
        return switch (slice.len) {
            1 => @as(u21, slice[0]),
            2 => (@as(u21, (slice[0] & 0x1F)) << 6) | (slice[1] & 0x3F),
            3 => (((@as(u21, (slice[0] & 0x0F)) << 6) | (slice[1] & 0x3F)) << 6) | (slice[2] & 0x3F),
            else => (((((@as(u21, (slice[0] & 0x07)) << 6) | (slice[1] & 0x3F)) << 6) | (slice[2] & 0x3F)) << 6) | (slice[3] & 0x3F)
        };
    }

    pub inline fn getCodepointLength(cp: u21) u3 {
        return switch (cp) {
            0x00000...0x00007F => @as(u3, 1),
            0x00080...0x0007FF => @as(u3, 2),
            0x00800...0x00FFFF => @as(u3, 3),
            else => @as(u3, 4),
        };
    }

    pub inline fn isValidCodepoint(cp: u21) bool {
        return cp <= 0x10FFFF;
    }

    pub inline fn getSequenceLength(first_byte: u8) u3 {
        return switch (first_byte) {
            0x00...0x7F => @as(u3, 1),
            0xC0...0xDF => @as(u3, 2),
            0xE0...0xEF => @as(u3, 3),
            else => @as(u3, 4),
        };
    }
};

// ╔══════════════════════════════════════ FILE OPERATIONS ═══════════════════════════╗

pub const File = struct {
    file: std.fs.File,
    path: [256]u8, // Static path buffer
    path_len: usize,

    pub inline fn open(static_path: []const u8) !File {
        if (static_path.len > 256) return error.PathTooLong;
        var path_buffer: [256]u8 = undefined;
        @memcpy(path_buffer[0..static_path.len], static_path);
        const file = try std.fs.cwd().openFile(static_path, .{});
        return File{
            .file = file,
            .path = path_buffer,
            .path_len = static_path.len,
        };
    }

    pub inline fn create(static_path: []const u8) !File {
        if (static_path.len > 256) return error.PathTooLong;
        var path_buffer: [256]u8 = undefined;
        @memcpy(path_buffer[0..static_path.len], static_path);
        const file = try std.fs.cwd().createFile(static_path, .{});
        return File{
            .file = file,
            .path = path_buffer,
            .path_len = static_path.len,
        };
    }

    pub inline fn read(self: *const File, buffer: []u8) !usize {
        return self.file.read(buffer);
    }

    pub inline fn write(self: *const File, data: []const u8) !usize {
        return self.file.write(data);
    }

    pub inline fn seekTo(self: *const File, offset: u64) !void {
        return self.file.seekTo(offset);
    }

    pub inline fn getEndPos(self: *const File) !u64 {
        return self.file.getEndPos();
    }

    pub inline fn sync(self: *const File) !void {
        return self.file.sync();
    }

    pub inline fn close(self: *const File) void {
        self.file.close();
    }

    pub inline fn getPath(self: *const File) []const u8 {
        return self.path[0..self.path_len];
    }
};

// ╔══════════════════════════════════════ NETWORK OPERATIONS ════════════════════════╗

pub const Network = struct {
    pub const Server = struct {
        listener: std.net.StreamServer,
        port: u16,
        address: [64]u8, // Static address buffer
        address_len: usize,

        pub inline fn init(static_address: []const u8, static_port: u16) Server {
            var address_buffer: [64]u8 = undefined;
            if (static_address.len > 64) {
                @memset(address_buffer, 0);
            } else {
                @memcpy(address_buffer[0..static_address.len], static_address);
            }
            return Server{
                .listener = std.net.StreamServer.init(.{}),
                .port = static_port,
                .address = address_buffer,
                .address_len = @min(static_address.len, 64),
            };
        }

        pub inline fn listen(self: *Server) !void {
            try self.listener.listen(try std.net.Address.parseIp("0.0.0.0", self.port));
        }

        pub inline fn accept(self: *Server) !std.net.Stream {
            return self.listener.accept();
        }

        pub inline fn close(self: *Server) void {
            self.listener.deinit();
        }

        pub inline fn getAddress(self: *const Server) []const u8 {
            return self.address[0..self.address_len];
        }
    };
};

// ╔══════════════════════════════════════ TIME OPERATIONS ═══════════════════════════╗

pub const Time = struct {
    pub inline fn now() i64 {
        return std.time.milliTimestamp();
    }

    pub inline fn formatStatic(timestamp: i64, static_buffer: []u8) ![]u8 {
        if (static_buffer.len < 16) return error.BufferTooSmall;
        const formatted = std.fmt.bufPrint(static_buffer, "{d}", .{timestamp}) catch return error.BufferTooSmall;
        return formatted;
    }

    pub inline fn sleep(ms: u64) void {
        std.time.sleep(ms * std.time.ns_per_ms);
    }
};

// ╔══════════════════════════════════════ CLI OPERATIONS ════════════════════════════╗

pub const CLI = struct {
    pub inline fn promptStatic(comptime message: []const u8, static_buffer: []u8) ![]u8 {
        const stdout = std.io.getStdOut();
        try stdout.writer().print("{s}", .{message});
        try stdout.writer().flush();

        const stdin = std.io.getStdIn();
        var len: usize = 0;
        while (len < static_buffer.len) {
            const byte = stdin.reader().readByte() catch break;
            if (byte == '\n') break;
            static_buffer[len] = byte;
            len += 1;
        }
        return static_buffer[0..len];
    }

    pub inline fn confirm(comptime message: []const u8) !bool {
        var buffer: [256]u8 = undefined;
        const input = try promptStatic(message ++ " (y/N): ", &buffer);
        const response = String.trim(input);
        return std.mem.eql(u8, response, "y") or std.mem.eql(u8, response, "Y") or std.mem.eql(u8, response, "yes");
    }
};

// ╚══════════════════════════════════════════════════════════════════════════════════╝
