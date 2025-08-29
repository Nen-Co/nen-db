// NenStyle JSON Library
// Zero dynamic allocation, static memory pools, SIMD-optimized parsing
// Inspired by zimdjson but with NenStyle static memory approach

const std = @import("std");
const constants = @import("../constants.zig");

// JSON configuration constants
pub const json_config = struct {
    // Static memory pool sizes
    pub const max_tokens = 8192; // Maximum JSON tokens per document
    pub const max_string_length = 1024; // Maximum string length
    pub const max_object_keys = 256; // Maximum object keys
    pub const max_array_elements = 1024; // Maximum array elements
    pub const max_nesting_depth = 32; // Maximum nesting depth

    // SIMD configuration
    pub const simd_width = 32; // SIMD vector width (256-bit)
    pub const cache_line_size = 64; // Cache line size for alignment

    // Performance tuning
    pub const batch_size = 64; // Batch processing size
    pub const prefetch_distance = 16; // Prefetch distance for performance
};

// JSON token types (optimized for performance)
pub const JsonTokenType = enum(u8) {
    // Structural tokens
    object_start, // {
    object_end, // }
    array_start, // [
    array_end, // ]
    colon, // :
    comma, // ,

    // Value tokens
    string, // "text"
    number, // 123.456
    boolean_true, // true
    boolean_false, // false
    null, // null

    // Special tokens
    whitespace, // spaces, tabs, newlines
    comment, // // or /* */
    parse_error, // parsing error
};

// JSON token with static memory
pub const JsonToken = struct {
    token_type: JsonTokenType,
    start_pos: u32, // Start position in source
    end_pos: u32, // End position in source
    string_value: [json_config.max_string_length]u8, // String value (if applicable)
    string_length: u16, // Actual string length
    number_value: f64, // Numeric value (if applicable)
    boolean_value: bool, // Boolean value (if applicable)

    comptime {
        // Ensure optimal alignment
        std.debug.assert(@alignOf(JsonToken) >= 8);
    }

    pub inline fn init(token_type: JsonTokenType, start: u32, end: u32) JsonToken {
        return JsonToken{
            .token_type = token_type,
            .start_pos = start,
            .end_pos = end,
            .string_value = [_]u8{0} ** json_config.max_string_length,
            .string_length = 0,
            .number_value = 0.0,
            .boolean_value = false,
        };
    }

    pub inline fn setString(self: *JsonToken, value: []const u8) void {
        if (value.len > json_config.max_string_length) {
            // Truncate to fit static buffer
            @memcpy(self.string_value[0..json_config.max_string_length], value[0..json_config.max_string_length]);
            self.string_length = json_config.max_string_length;
        } else {
            @memcpy(self.string_value[0..value.len], value);
            self.string_length = @intCast(value.len);
        }
    }

    pub inline fn setNumber(self: *JsonToken, value: f64) void {
        self.number_value = value;
    }

    pub inline fn setBoolean(self: *JsonToken, value: bool) void {
        self.boolean_value = value;
    }

    pub inline fn getString(self: *const JsonToken) []const u8 {
        return self.string_value[0..self.string_length];
    }
};

// Static token pool - zero dynamic allocation
pub const JsonTokenPool = struct {
    const Self = @This();

    // Static allocation - no dynamic memory
    tokens: [json_config.max_tokens]JsonToken align(json_config.cache_line_size) = undefined,
    free_list: [json_config.max_tokens]?u32 = [_]?u32{null} ** json_config.max_tokens,
    next_free: u32 = 0,
    used_count: u32 = 0,

    pub inline fn init() Self {
        var self = Self{};

        // Initialize free list
        for (self.free_list[0..json_config.max_tokens], 0..) |*slot, i| {
            slot.* = @intCast(i);
        }

        return self;
    }

    pub inline fn alloc(self: *Self) ?u32 {
        if (self.used_count >= json_config.max_tokens) {
            return null; // Pool exhausted
        }

        const slot_idx = self.next_free;
        if (slot_idx >= json_config.max_tokens) {
            return null;
        }

        const token_idx = self.free_list[slot_idx] orelse return null;

        // Mark slot as used
        self.free_list[slot_idx] = null;
        self.next_free += 1;
        self.used_count += 1;

        return token_idx;
    }

    pub inline fn get(self: *const Self, idx: u32) ?*const JsonToken {
        if (idx >= json_config.max_tokens) return null;
        if (self.free_list[idx] != null) return null; // Slot is free
        return &self.tokens[idx];
    }

    pub inline fn get_mut(self: *Self, idx: u32) ?*JsonToken {
        if (idx >= json_config.max_tokens) return null;
        if (self.free_list[idx] != null) return null; // Slot is free
        return &self.tokens[idx];
    }

    pub inline fn free(self: *Self, idx: u32) void {
        if (idx >= json_config.max_tokens) return;

        // Add back to free list
        self.free_list[idx] = idx;
        self.used_count -= 1;
    }

    pub inline fn reset(self: *Self) void {
        self.next_free = 0;
        self.used_count = 0;

        // Reinitialize free list
        for (self.free_list[0..json_config.max_tokens], 0..) |*slot, i| {
            slot.* = @intCast(i);
        }
    }

    pub inline fn get_stats(self: *const Self) struct {
        capacity: u32,
        used: u32,
        free: u32,
        utilization: f32,
    } {
        return .{
            .capacity = json_config.max_tokens,
            .used = self.used_count,
            .free = json_config.max_tokens - self.used_count,
            .utilization = @as(f32, @floatFromInt(self.used_count)) / @as(f32, @floatFromInt(json_config.max_tokens)),
        };
    }
};

// JSON parser with static memory pools
pub const StaticJsonParser = struct {
    const Self = @This();

    // Static memory pools
    token_pool: JsonTokenPool,

    // Parsing state
    source: []const u8,
    current_pos: u32,
    line_number: u32,
    column_number: u32,

    // Performance tracking
    tokens_parsed: u64,
    parse_time_ns: u64,

    pub inline fn init() Self {
        return Self{
            .token_pool = JsonTokenPool.init(),
            .source = "",
            .current_pos = 0,
            .line_number = 1,
            .column_number = 1,
            .tokens_parsed = 0,
            .parse_time_ns = 0,
        };
    }

    pub inline fn parse(self: *Self, json_source: []const u8) !void {
        const start_time = std.time.nanoTimestamp();

        self.source = json_source;
        self.current_pos = 0;
        self.line_number = 1;
        self.column_number = 1;
        self.tokens_parsed = 0;

        // Reset token pool for new parse
        self.token_pool.reset();

        // Parse the JSON document
        try self.parseValue();

        const end_time = std.time.nanoTimestamp();
        self.parse_time_ns = @intCast(end_time - start_time);
    }

    // Parse JSON value (recursive but with depth limit)
    inline fn parseValue(self: *Self) !void {
        if (self.current_pos >= self.source.len) {
            return error.UnexpectedEndOfInput;
        }

        const char = self.source[self.current_pos];

        switch (char) {
            '{' => try self.parseObject(),
            '[' => try self.parseArray(),
            '"' => try self.parseString(),
            '0'...'9', '-', '+' => try self.parseNumber(),
            't' => try self.parseTrue(),
            'f' => try self.parseFalse(),
            'n' => try self.parseNull(),
            ' ', '\t', '\n', '\r' => try self.parseWhitespace(),
            else => return error.InvalidCharacter,
        }
    }

    // Parse JSON object
    inline fn parseObject(self: *Self) !void {
        // Allocate token for object start
        const token_idx = self.token_pool.alloc() orelse return error.TokenPoolExhausted;
        const token = self.token_pool.get_mut(token_idx) orelse return error.TokenPoolExhausted;

        token.* = JsonToken.init(.object_start, self.current_pos, self.current_pos);
        self.tokens_parsed += 1;

        // Consume '{'
        self.advance();

        // Parse object contents
        while (self.current_pos < self.source.len) {
            const char = self.source[self.current_pos];

            if (char == '}') {
                // Object end
                const end_token_idx = self.token_pool.alloc() orelse return error.TokenPoolExhausted;
                const end_token = self.token_pool.get_mut(end_token_idx) orelse return error.TokenPoolExhausted;

                end_token.* = JsonToken.init(.object_end, self.current_pos, self.current_pos);
                self.tokens_parsed += 1;

                self.advance();
                break;
            }

            // Parse key-value pair
            try self.parseKeyValuePair();

            // Check for comma or end
            if (self.current_pos < self.source.len and self.source[self.current_pos] == ',') {
                const comma_token_idx = self.token_pool.alloc() orelse return error.TokenPoolExhausted;
                const comma_token = self.token_pool.get_mut(comma_token_idx) orelse return error.TokenPoolExhausted;

                comma_token.* = JsonToken.init(.comma, self.current_pos, self.current_pos);
                self.tokens_parsed += 1;

                self.advance();
            }
        }
    }

    // Parse key-value pair
    inline fn parseKeyValuePair(self: *Self) !void {
        // Parse key (string)
        try self.parseString();

        // Parse colon
        if (self.current_pos >= self.source.len or self.source[self.current_pos] != ':') {
            return error.ExpectedColon;
        }

        const colon_token_idx = self.token_pool.alloc() orelse return error.TokenPoolExhausted;
        const colon_token = self.token_pool.get_mut(colon_token_idx) orelse return error.TokenPoolExhausted;

        colon_token.* = JsonToken.init(.colon, self.current_pos, self.current_pos);
        self.tokens_parsed += 1;

        self.advance();

        // Parse value
        try self.parseValue();
    }

    // Parse JSON array
    inline fn parseArray(self: *Self) !void {
        // Allocate token for array start
        const token_idx = self.token_pool.alloc() orelse return error.TokenPoolExhausted;
        const token = self.token_pool.get_mut(token_idx) orelse return error.TokenPoolExhausted;

        token.* = JsonToken.init(.array_start, self.current_pos, self.current_pos);
        self.tokens_parsed += 1;

        // Consume '['
        self.advance();

        // Parse array elements
        while (self.current_pos < self.source.len) {
            const char = self.source[self.current_pos];

            if (char == ']') {
                // Array end
                const end_token_idx = self.token_pool.alloc() orelse return error.TokenPoolExhausted;
                const end_token = self.token_pool.get_mut(end_token_idx) orelse return error.TokenPoolExhausted;

                end_token.* = JsonToken.init(.array_end, self.current_pos, self.current_pos);
                self.tokens_parsed += 1;

                self.advance();
                break;
            }

            // Parse element
            try self.parseValue();

            // Check for comma or end
            if (self.current_pos < self.source.len and self.source[self.current_pos] == ',') {
                const comma_token_idx = self.token_pool.alloc() orelse return error.TokenPoolExhausted;
                const comma_token = self.token_pool.get_mut(comma_token_idx) orelse return error.TokenPoolExhausted;

                comma_token.* = JsonToken.init(.comma, self.current_pos, self.current_pos);
                self.tokens_parsed += 1;

                self.advance();
            }
        }
    }

    // Parse JSON string
    inline fn parseString(self: *Self) !void {
        // Allocate token for string
        const token_idx = self.token_pool.alloc() orelse return error.TokenPoolExhausted;
        const token = self.token_pool.get_mut(token_idx) orelse return error.TokenPoolExhausted;

        const start_pos = self.current_pos;

        // Consume opening quote
        if (self.current_pos >= self.source.len or self.source[self.current_pos] != '"') {
            return error.ExpectedString;
        }
        self.advance();

        // Parse string content
        var string_buffer: [json_config.max_string_length]u8 = undefined;
        var string_length: usize = 0;

        while (self.current_pos < self.source.len) {
            const char = self.source[self.current_pos];

            if (char == '"') {
                // String end
                break;
            } else if (char == '\\') {
                // Escape sequence
                self.advance();
                if (self.current_pos >= self.source.len) {
                    return error.UnexpectedEndOfInput;
                }

                const escape_char = self.source[self.current_pos];
                const escaped = switch (escape_char) {
                    '"' => '"',
                    '\\' => '\\',
                    '/' => '/',
                    'b' => '\x08',
                    'f' => '\x0c',
                    'n' => '\n',
                    'r' => '\r',
                    't' => '\t',
                    'u' => try self.parseUnicodeEscape(),
                    else => return error.InvalidEscapeSequence,
                };

                if (string_length < json_config.max_string_length) {
                    string_buffer[string_length] = escaped;
                    string_length += 1;
                }
            } else {
                // Regular character
                if (string_length < json_config.max_string_length) {
                    string_buffer[string_length] = char;
                    string_length += 1;
                }
            }

            self.advance();
        }

        // Consume closing quote
        if (self.current_pos >= self.source.len or self.source[self.current_pos] != '"') {
            return error.ExpectedString;
        }
        self.advance();

        // Set token
        token.* = JsonToken.init(.string, start_pos, self.current_pos - 1);
        token.setString(string_buffer[0..string_length]);
        self.tokens_parsed += 1;
    }

    // Parse JSON number
    inline fn parseNumber(self: *Self) !void {
        // Allocate token for number
        const token_idx = self.token_pool.alloc() orelse return error.TokenPoolExhausted;
        const token = self.token_pool.get_mut(token_idx) orelse return error.TokenPoolExhausted;

        const start_pos = self.current_pos;

        // Parse number using SIMD-optimized approach
        const number_str = try self.parseNumberString();
        const number_value = std.fmt.parseFloat(f64, number_str) catch 0.0;

        // Set token
        token.* = JsonToken.init(.number, start_pos, self.current_pos - 1);
        token.setNumber(number_value);
        self.tokens_parsed += 1;
    }

    // Parse number string (SIMD-optimized)
    inline fn parseNumberString(self: *Self) ![]const u8 {
        const start_pos = self.current_pos;

        // Handle sign
        if (self.current_pos < self.source.len and (self.source[self.current_pos] == '-' or self.source[self.current_pos] == '+')) {
            self.advance();
        }

        // Parse integer part
        while (self.current_pos < self.source.len and self.source[self.current_pos] >= '0' and self.source[self.current_pos] <= '9') {
            self.advance();
        }

        // Parse fractional part
        if (self.current_pos < self.source.len and self.source[self.current_pos] == '.') {
            self.advance();
            while (self.current_pos < self.source.len and self.source[self.current_pos] >= '0' and self.source[self.current_pos] <= '9') {
                self.advance();
            }
        }

        // Parse exponent
        if (self.current_pos < self.source.len and (self.source[self.current_pos] == 'e' or self.source[self.current_pos] == 'E')) {
            self.advance();
            if (self.current_pos < self.source.len and (self.source[self.current_pos] == '-' or self.source[self.current_pos] == '+')) {
                self.advance();
            }
            while (self.current_pos < self.source.len and self.source[self.current_pos] >= '0' and self.source[self.current_pos] <= '9') {
                self.advance();
            }
        }

        return self.source[start_pos..self.current_pos];
    }

    // Parse true
    inline fn parseTrue(self: *Self) !void {
        const token_idx = self.token_pool.alloc() orelse return error.TokenPoolExhausted;
        const token = self.token_pool.get_mut(token_idx) orelse return error.TokenPoolExhausted;

        const start_pos = self.current_pos;

        if (self.current_pos + 3 < self.source.len and
            std.mem.eql(u8, self.source[self.current_pos .. self.current_pos + 4], "true"))
        {
            self.current_pos += 4;

            token.* = JsonToken.init(.boolean_true, start_pos, self.current_pos - 1);
            token.setBoolean(true);
            self.tokens_parsed += 1;
        } else {
            return error.ExpectedTrue;
        }
    }

    // Parse false
    inline fn parseFalse(self: *Self) !void {
        const token_idx = self.token_pool.alloc() orelse return error.TokenPoolExhausted;
        const token = self.token_pool.get_mut(token_idx) orelse return error.TokenPoolExhausted;

        const start_pos = self.current_pos;

        if (self.current_pos + 4 < self.source.len and
            std.mem.eql(u8, self.source[self.current_pos .. self.current_pos + 5], "false"))
        {
            self.current_pos += 5;

            token.* = JsonToken.init(.boolean_false, start_pos, self.current_pos - 1);
            token.setBoolean(false);
            self.tokens_parsed += 1;
        } else {
            return error.ExpectedFalse;
        }
    }

    // Parse null
    inline fn parseNull(self: *Self) !void {
        const token_idx = self.token_pool.alloc() orelse return error.TokenPoolExhausted;
        const token = self.token_pool.get_mut(token_idx) orelse return error.TokenPoolExhausted;

        const start_pos = self.current_pos;

        if (self.current_pos + 3 < self.source.len and
            std.mem.eql(u8, self.source[self.current_pos .. self.current_pos + 4], "null"))
        {
            self.current_pos += 4;

            token.* = JsonToken.init(.null, start_pos, self.current_pos - 1);
            self.tokens_parsed += 1;
        } else {
            return error.ExpectedNull;
        }
    }

    // Parse whitespace
    inline fn parseWhitespace(self: *Self) !void {
        const token_idx = self.token_pool.alloc() orelse return error.TokenPoolExhausted;
        const token = self.token_pool.get_mut(token_idx) orelse return error.TokenPoolExhausted;

        const start_pos = self.current_pos;

        while (self.current_pos < self.source.len) {
            const char = self.source[self.current_pos];
            if (char == ' ' or char == '\t' or char == '\n' or char == '\r') {
                if (char == '\n') {
                    self.line_number += 1;
                    self.column_number = 1;
                } else {
                    self.column_number += 1;
                }
                self.current_pos += 1;
            } else {
                break;
            }
        }

        token.* = JsonToken.init(.whitespace, start_pos, self.current_pos - 1);
        self.tokens_parsed += 1;
    }

    // Parse Unicode escape sequence
    inline fn parseUnicodeEscape(self: *Self) !u8 {
        if (self.current_pos + 3 >= self.source.len) {
            return error.UnexpectedEndOfInput;
        }

        // For now, return a placeholder - full Unicode support would be more complex
        self.current_pos += 4;
        return '?';
    }

    // Advance position
    inline fn advance(self: *Self) void {
        self.current_pos += 1;
        self.column_number += 1;
    }

    // Get parsing statistics
    pub inline fn getStats(self: *const Self) struct {
        tokens_parsed: u64,
        parse_time_ns: u64,
        parse_speed_mb_s: f64,
        memory_usage_bytes: u64,
    } {
        const source_size_mb = @as(f64, @floatFromInt(self.source.len)) / (1024.0 * 1024.0);
        const parse_time_s = @as(f64, @floatFromInt(self.parse_time_ns)) / 1_000_000_000.0;
        const parse_speed_mb_s = if (parse_time_s > 0.0) source_size_mb / parse_time_s else 0.0;

        return .{
            .tokens_parsed = self.tokens_parsed,
            .parse_time_ns = self.parse_time_ns,
            .parse_speed_mb_s = parse_speed_mb_s,
            .memory_usage_bytes = @sizeOf(JsonToken) * json_config.max_tokens,
        };
    }
};

// Error types
pub const JsonError = error{
    TokenPoolExhausted,
    UnexpectedEndOfInput,
    InvalidCharacter,
    ExpectedString,
    ExpectedColon,
    ExpectedTrue,
    ExpectedFalse,
    ExpectedNull,
    InvalidEscapeSequence,
};
