// NenStyle JSON API for Graph Database
// High-level interface for JSON operations with static memory pools
// Integrates with NenDB nodes and edges

const std = @import("std");
const static_json = @import("static_json.zig");
const constants = @import("../constants.zig");

// JSON value types that can be stored in graph properties
pub const JsonValue = union(enum) {
    string: []const u8,
    number: f64,
    boolean: bool,
    null: void,
    object: JsonObject,
    array: JsonArray,

    pub inline fn deinit(self: *JsonValue) void {
        switch (self.*) {
            .string => {}, // No allocation to free
            .number => {},
            .boolean => {},
            .null => {},
            .object => self.object.deinit(),
            .array => self.array.deinit(),
        }
    }

    pub inline fn getString(self: *const JsonValue) ?[]const u8 {
        return switch (self.*) {
            .string => |s| s,
            else => null,
        };
    }

    pub inline fn getNumber(self: *const JsonValue) ?f64 {
        return switch (self.*) {
            .number => |n| n,
            else => null,
        };
    }

    pub inline fn getBoolean(self: *const JsonValue) ?bool {
        return switch (self.*) {
            .boolean => |b| b,
            else => null,
        };
    }

    pub inline fn isNull(self: *const JsonValue) bool {
        return switch (self.*) {
            .null => true,
            else => false,
        };
    }

    pub inline fn getObject(self: *const JsonValue) ?*const JsonObject {
        return switch (self.*) {
            .object => |*obj| obj,
            else => null,
        };
    }

    pub inline fn getArray(self: *const JsonValue) ?*const JsonArray {
        return switch (self.*) {
            .array => |*arr| arr,
            else => null,
        };
    }
};

// JSON object with static memory pool
pub const JsonObject = struct {
    const Self = @This();

    // Static key-value storage
    keys: [static_json.json_config.max_object_keys][]const u8 = undefined,
    values: [static_json.json_config.max_object_keys]JsonValue = undefined,
    count: u16 = 0,

    pub inline fn init() Self {
        return Self{};
    }

    pub inline fn deinit(self: *Self) void {
        // No dynamic allocation to free
        _ = self;
    }

    pub inline fn set(self: *Self, key: []const u8, value: JsonValue) !void {
        if (self.count >= static_json.json_config.max_object_keys) {
            return error.ObjectTooLarge;
        }

        // Check if key already exists
        for (0..self.count) |i| {
            if (std.mem.eql(u8, self.keys[i], key)) {
                // Update existing key
                self.values[i] = value;
                return;
            }
        }

        // Add new key-value pair
        self.keys[self.count] = key;
        self.values[self.count] = value;
        self.count += 1;
    }

    pub inline fn get(self: *const Self, key: []const u8) ?JsonValue {
        for (0..self.count) |i| {
            if (std.mem.eql(u8, self.keys[i], key)) {
                return self.values[i];
            }
        }
        return null;
    }

    pub inline fn has(self: *const Self, key: []const u8) bool {
        return self.get(key) != null;
    }

    pub inline fn remove(self: *Self, key: []const u8) bool {
        for (0..self.count) |i| {
            if (std.mem.eql(u8, self.keys[i], key)) {
                // Shift remaining elements
                for (i..self.count - 1) |j| {
                    self.keys[j] = self.keys[j + 1];
                    self.values[j] = self.values[j + 1];
                }
                self.count -= 1;
                return true;
            }
        }
        return false;
    }

    pub inline fn size(self: *const Self) u16 {
        return self.count;
    }

    pub inline fn isEmpty(self: *const Self) bool {
        return self.count == 0;
    }

    pub inline fn clear(self: *Self) void {
        self.count = 0;
    }

    // Iterator support
    pub inline fn iterator(self: *const Self) JsonObjectIterator {
        return JsonObjectIterator{
            .object = self,
            .index = 0,
        };
    }
};

// JSON object iterator
pub const JsonObjectIterator = struct {
    object: *const JsonObject,
    index: u16,

    pub inline fn next(self: *JsonObjectIterator) ?struct { key: []const u8, value: JsonValue } {
        if (self.index >= self.object.count) {
            return null;
        }

        const result = .{
            .key = self.object.keys[self.index],
            .value = self.object.values[self.index],
        };

        self.index += 1;
        return result;
    }

    pub inline fn reset(self: *JsonObjectIterator) void {
        self.index = 0;
    }
};

// JSON array with static memory pool
pub const JsonArray = struct {
    const Self = @This();

    // Static element storage
    elements: [static_json.json_config.max_array_elements]JsonValue = undefined,
    count: u16 = 0,

    pub inline fn init() Self {
        return Self{};
    }

    pub inline fn deinit(self: *Self) void {
        // No dynamic allocation to free
        _ = self;
    }

    pub inline fn append(self: *Self, value: JsonValue) !void {
        if (self.count >= static_json.json_config.max_array_elements) {
            return error.ArrayTooLarge;
        }

        self.elements[self.count] = value;
        self.count += 1;
    }

    pub inline fn get(self: *const Self, index: u16) ?JsonValue {
        if (index >= self.count) {
            return null;
        }
        return self.elements[index];
    }

    pub inline fn set(self: *Self, index: u16, value: JsonValue) !void {
        if (index >= static_json.json_config.max_array_elements) {
            return error.IndexOutOfBounds;
        }

        if (index >= self.count) {
            self.count = index + 1;
        }

        self.elements[index] = value;
    }

    pub inline fn remove(self: *Self, index: u16) bool {
        if (index >= self.count) {
            return false;
        }

        // Shift remaining elements
        for (index..self.count - 1) |i| {
            self.elements[i] = self.elements[i + 1];
        }

        self.count -= 1;
        return true;
    }

    pub inline fn size(self: *const Self) u16 {
        return self.count;
    }

    pub inline fn isEmpty(self: *const Self) bool {
        return self.count == 0;
    }

    pub inline fn clear(self: *Self) void {
        self.count = 0;
    }

    // Iterator support
    pub inline fn iterator(self: *const Self) JsonArrayIterator {
        return JsonArrayIterator{
            .array = self,
            .index = 0,
        };
    }
};

// JSON array iterator
pub const JsonArrayIterator = struct {
    array: *const JsonArray,
    index: u16,

    pub inline fn next(self: *JsonArrayIterator) ?JsonValue {
        if (self.index >= self.array.count) {
            return null;
        }

        const value = self.array.elements[self.index];
        self.index += 1;
        return value;
    }

    pub inline fn reset(self: *JsonArrayIterator) void {
        self.index = 0;
    }
};

// High-level JSON parser that creates JsonValue objects
pub const JsonParser = struct {
    const Self = @This();

    // Static parser
    parser: static_json.StaticJsonParser,

    pub inline fn init() Self {
        return Self{
            .parser = static_json.StaticJsonParser.init(),
        };
    }

    pub inline fn deinit(self: *Self) void {
        // No dynamic allocation to free
        _ = self;
    }

    // Parse JSON string into JsonValue
    pub inline fn parse(self: *Self, json_string: []const u8) !JsonValue {
        try self.parser.parse(json_string);

        // Convert tokens to JsonValue
        return try self.tokensToValue(0);
    }

    // Convert parsed tokens to JsonValue
    inline fn tokensToValue(self: *Self, start_token: u32) !JsonValue {
        const token = self.parser.token_pool.get(start_token) orelse {
            return error.InvalidToken;
        };

        return switch (token.token_type) {
            .string => JsonValue{ .string = token.getString() },
            .number => JsonValue{ .number = token.number_value },
            .boolean_true => JsonValue{ .boolean = true },
            .boolean_false => JsonValue{ .boolean = false },
            .null => JsonValue{ .null = {} },
            .object_start => try self.parseObject(start_token + 1),
            .array_start => try self.parseArray(start_token + 1),
            else => return error.UnexpectedToken,
        };
    }

    // Parse object from tokens
    inline fn parseObject(self: *Self, start_token: u32) !JsonValue {
        var object = JsonObject.init();
        var current_token = start_token;

        while (current_token < self.parser.token_pool.used_count) {
            const token = self.parser.token_pool.get(current_token) orelse break;

            if (token.token_type == .object_end) {
                break;
            }

            // Parse key
            if (token.token_type != .string) {
                return error.ExpectedStringKey;
            }
            const key = token.getString();
            current_token += 1;

            // Parse colon
            const colon_token = self.parser.token_pool.get(current_token) orelse break;
            if (colon_token.token_type != .colon) {
                return error.ExpectedColon;
            }
            current_token += 1;

            // Parse value
            const value = try self.tokensToValue(current_token);
            try object.set(key, value);

            // Skip to next key-value pair
            while (current_token < self.parser.token_pool.used_count) {
                const next_token = self.parser.token_pool.get(current_token) orelse break;
                if (next_token.token_type == .comma) {
                    current_token += 1;
                    break;
                } else if (next_token.token_type == .object_end) {
                    break;
                }
                current_token += 1;
            }
        }

        return JsonValue{ .object = object };
    }

    // Parse array from tokens
    inline fn parseArray(self: *Self, start_token: u32) !JsonValue {
        var array = JsonArray.init();
        var current_token = start_token;

        while (current_token < self.parser.token_pool.used_count) {
            const token = self.parser.token_pool.get(current_token) orelse break;

            if (token.token_type == .array_end) {
                break;
            }

            // Parse element
            const element = try self.tokensToValue(current_token);
            try array.append(element);

            // Skip to next element
            while (current_token < self.parser.token_pool.used_count) {
                const next_token = self.parser.token_pool.get(current_token) orelse break;
                if (next_token.token_type == .comma) {
                    current_token += 1;
                    break;
                } else if (next_token.token_type == .array_end) {
                    break;
                }
                current_token += 1;
            }
        }

        return JsonValue{ .array = array };
    }

    // Get parsing statistics
    pub inline fn getStats(self: *const Self) static_json.StaticJsonParser.Stats {
        return self.parser.getStats();
    }
};

// JSON builder for creating JSON structures
pub const JsonBuilder = struct {
    const Self = @This();

    pub inline fn object() JsonObject {
        return JsonObject.init();
    }

    pub inline fn array() JsonArray {
        return JsonArray.init();
    }

    pub inline fn string(value: []const u8) JsonValue {
        return JsonValue{ .string = value };
    }

    pub inline fn number(value: f64) JsonValue {
        return JsonValue{ .number = value };
    }

    pub inline fn boolean(value: bool) JsonValue {
        return JsonValue{ .boolean = value };
    }

    pub inline fn @"null"() JsonValue {
        return JsonValue{ .null = {} };
    }

    // Helper for building objects
    pub inline fn buildObject(comptime fields: anytype) JsonObject {
        var obj = JsonObject.init();

        inline for (fields) |field| {
            const value = switch (@TypeOf(field.value)) {
                []const u8 => JsonValue{ .string = field.value },
                f64 => JsonValue{ .number = field.value },
                bool => JsonValue{ .boolean = field.value },
                JsonObject => JsonValue{ .object = field.value },
                JsonArray => JsonValue{ .array = field.value },
                else => JsonValue{ .null = {} },
            };

            obj.set(field.name, value) catch {};
        }

        return obj;
    }

    // Helper for building arrays
    pub inline fn buildArray(comptime elements: anytype) JsonArray {
        var arr = JsonArray.init();

        inline for (elements) |element| {
            const value = switch (@TypeOf(element)) {
                []const u8 => JsonValue{ .string = element },
                f64 => JsonValue{ .number = element },
                bool => JsonValue{ .boolean = element },
                JsonObject => JsonValue{ .object = element },
                JsonArray => JsonValue{ .array = element },
                else => JsonValue{ .null = {} },
            };

            arr.append(value) catch {};
        }

        return arr;
    }
};

// JSON serialization (convert JsonValue back to string)
pub const JsonSerializer = struct {
    const Self = @This();

    // Static buffer for serialization
    buffer: [constants.data.node_props_size]u8 = undefined,
    position: usize = 0,

    pub inline fn init() Self {
        return Self{};
    }

    pub inline fn deinit(self: *Self) void {
        // No dynamic allocation to free
        _ = self;
    }

    // Serialize JsonValue to string
    pub inline fn serialize(self: *Self, value: JsonValue) ![]const u8 {
        self.position = 0;
        try self.serializeValue(value);
        return self.buffer[0..self.position];
    }

    // Serialize individual value
    inline fn serializeValue(self: *Self, value: JsonValue) !void {
        switch (value) {
            .string => |s| try self.writeString(s),
            .number => |n| try self.writeNumber(n),
            .boolean => |b| try self.writeBoolean(b),
            .null => try self.writeNull(),
            .object => |obj| try self.writeObject(obj),
            .array => |arr| try self.writeArray(arr),
        }
    }

    // Write string to buffer
    inline fn writeString(self: *Self, s: []const u8) !void {
        if (self.position + s.len + 2 > self.buffer.len) {
            return error.BufferTooSmall;
        }

        self.buffer[self.position] = '"';
        self.position += 1;

        @memcpy(self.buffer[self.position .. self.position + s.len], s);
        self.position += s.len;

        self.buffer[self.position] = '"';
        self.position += 1;
    }

    // Write number to buffer
    inline fn writeNumber(self: *Self, n: f64) !void {
        const num_str = try std.fmt.bufPrint(self.buffer[self.position..], "{d}", .{n});
        self.position += num_str.len;
    }

    // Write boolean to buffer
    inline fn writeBoolean(self: *Self, b: bool) !void {
        const bool_str = if (b) "true" else "false";
        if (self.position + bool_str.len > self.buffer.len) {
            return error.BufferTooSmall;
        }

        @memcpy(self.buffer[self.position .. self.position + bool_str.len], bool_str);
        self.position += bool_str.len;
    }

    // Write null to buffer
    inline fn writeNull(self: *Self) !void {
        const null_str = "null";
        if (self.position + null_str.len > self.buffer.len) {
            return error.BufferTooSmall;
        }

        @memcpy(self.buffer[self.position .. self.position + null_str.len], null_str);
        self.position += null_str.len;
    }

    // Write object to buffer
    inline fn writeObject(self: *Self, obj: JsonObject) !void {
        if (self.position + 1 > self.buffer.len) {
            return error.BufferTooSmall;
        }

        self.buffer[self.position] = '{';
        self.position += 1;

        var it = obj.iterator();
        var first = true;

        while (it.next()) |kv| {
            if (!first) {
                if (self.position + 1 > self.buffer.len) {
                    return error.BufferTooSmall;
                }
                self.buffer[self.position] = ',';
                self.position += 1;
            }

            try self.writeString(kv.key);

            if (self.position + 1 > self.buffer.len) {
                return error.BufferTooSmall;
            }
            self.buffer[self.position] = ':';
            self.position += 1;

            try self.serializeValue(kv.value);
            first = false;
        }

        if (self.position + 1 > self.buffer.len) {
            return error.BufferTooSmall;
        }
        self.buffer[self.position] = '}';
        self.position += 1;
    }

    // Write array to buffer
    inline fn writeArray(self: *Self, arr: JsonArray) !void {
        if (self.position + 1 > self.buffer.len) {
            return error.BufferTooSmall;
        }

        self.buffer[self.position] = '[';
        self.position += 1;

        var it = arr.iterator();
        var first = true;

        while (it.next()) |element| {
            if (!first) {
                if (self.position + 1 > self.buffer.len) {
                    return error.BufferTooSmall;
                }
                self.buffer[self.position] = ',';
                self.position += 1;
            }

            try self.serializeValue(element);
            first = false;
        }

        if (self.position + 1 > self.buffer.len) {
            return error.BufferTooSmall;
        }
        self.buffer[self.position] = ']';
        self.position += 1;
    }
};

// Error types
pub const JsonApiError = error{
    ObjectTooLarge,
    ArrayTooLarge,
    IndexOutOfBounds,
    BufferTooSmall,
    InvalidToken,
    UnexpectedToken,
    ExpectedStringKey,
    ExpectedColon,
};
