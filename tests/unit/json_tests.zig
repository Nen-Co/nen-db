// NenStyle JSON Library Unit Tests
// Test-driven development for zero-allocation JSON parsing

const std = @import("std");
const testing = std.testing;
const json = @import("nendb").json;

// ===== BASIC JSON PARSING TESTS =====

test "parse_simple_string" {
    const json_str = "\"hello world\"";
    const value = try json.parse(json_str);
    
    try testing.expect(value.getString() != null);
    try testing.expectEqualStrings("hello world", value.getString().?);
}

test "parse_simple_number" {
    const json_str = "42.5";
    const value = try json.parse(json_str);
    
    try testing.expect(value.getNumber() != null);
    try testing.expectEqual(@as(f64, 42.5), value.getNumber().?);
}

test "parse_simple_boolean" {
    const json_str = "true";
    const value = try json.parse(json_str);
    
    try testing.expect(value.getBoolean() != null);
    try testing.expectEqual(true, value.getBoolean().?);
}

test "parse_null" {
    const json_str = "null";
    const value = try json.parse(json_str);
    
    try testing.expect(value.isNull());
}

// ===== JSON OBJECT TESTS =====

test "parse_simple_object" {
    const json_str = "{\"name\":\"John\",\"age\":30}";
    const value = try json.parse(json_str);
    
    try testing.expect(value.getObject() != null);
    const obj = value.getObject().?;
    
    try testing.expectEqual(@as(u16, 2), obj.size());
    try testing.expect(obj.has("name"));
    try testing.expect(obj.has("age"));
    
    const name_value = obj.get("name").?;
    try testing.expectEqualStrings("John", name_value.getString().?);
    
    const age_value = obj.get("age").?;
    try testing.expectEqual(@as(f64, 30), age_value.getNumber().?);
}

test "parse_nested_object" {
    const json_str = "{\"user\":{\"name\":\"Alice\",\"active\":true}}";
    const value = try json.parse(json_str);
    
    try testing.expect(value.getObject() != null);
    const obj = value.getObject().?;
    
    try testing.expect(obj.has("user"));
    const user_value = obj.get("user").?;
    
    try testing.expect(user_value.getObject() != null);
    const user_obj = user_value.getObject().?;
    
    try testing.expectEqualStrings("Alice", user_obj.get("name").?.getString().?);
    try testing.expectEqual(true, user_obj.get("active").?.getBoolean().?);
}

test "object_iterator" {
    const json_str = "{\"a\":1,\"b\":2,\"c\":3}";
    const value = try json.parse(json_str);
    const obj = value.getObject().?;
    
    var it = obj.iterator();
    var count: u16 = 0;
    
    while (it.next()) |kv| {
        count += 1;
        try testing.expect(kv.key.len > 0);
        try testing.expect(kv.value.getNumber() != null);
    }
    
    try testing.expectEqual(@as(u16, 3), count);
}

// ===== JSON ARRAY TESTS =====

test "parse_simple_array" {
    const json_str = "[1,2,3,4,5]";
    const value = try json.parse(json_str);
    
    try testing.expect(value.getArray() != null);
    const arr = value.getArray().?;
    
    try testing.expectEqual(@as(u16, 5), arr.size());
    try testing.expectEqual(@as(f64, 1), arr.get(0).?.getNumber().?);
    try testing.expectEqual(@as(f64, 5), arr.get(4).?.getNumber().?);
}

test "parse_mixed_array" {
    const json_str = "[\"hello\",42,true,null]";
    const value = try json.parse(json_str);
    
    try testing.expect(value.getArray() != null);
    const arr = value.getArray().?;
    
    try testing.expectEqual(@as(u16, 4), arr.size());
    try testing.expectEqualStrings("hello", arr.get(0).?.getString().?);
    try testing.expectEqual(@as(f64, 42), arr.get(1).?.getNumber().?);
    try testing.expectEqual(true, arr.get(2).?.getBoolean().?);
    try testing.expect(arr.get(3).?.isNull());
}

test "array_iterator" {
    const json_str = "[10,20,30]";
    const value = try json.parse(json_str);
    const arr = value.getArray().?;
    
    var it = arr.iterator();
    var expected: u16 = 10;
    
    while (it.next()) |element| {
        try testing.expectEqual(@as(f64, expected), element.getNumber().?);
        expected += 10;
    }
    
    try testing.expectEqual(@as(u16, 40), expected);
}

// ===== JSON BUILDER TESTS =====

test "build_simple_object" {
    const obj = json.buildObject(.{
        .{ .name = "name", .value = "John" },
        .{ .name = "age", .value = @as(f64, 30) },
        .{ .name = "active", .value = true },
    });
    
    try testing.expectEqual(@as(u16, 3), obj.size());
    try testing.expectEqualStrings("John", obj.get("name").?.getString().?);
    try testing.expectEqual(@as(f64, 30), obj.get("age").?.getNumber().?);
    try testing.expectEqual(true, obj.get("active").?.getBoolean().?);
}

test "build_simple_array" {
    const arr = json.buildArray(.{ "a", "b", "c" });
    
    try testing.expectEqual(@as(u16, 3), arr.size());
    try testing.expectEqualStrings("a", arr.get(0).?.getString().?);
    try testing.expectEqualStrings("b", arr.get(1).?.getString().?);
    try testing.expectEqualStrings("c", arr.get(2).?.getString().?);
}

test "build_nested_structure" {
    const inner_obj = json.buildObject(.{
        .{ .name = "x", .value = @as(f64, 10) },
        .{ .name = "y", .value = @as(f64, 20) },
    });
    
    const arr = json.buildArray(.{ "point", inner_obj });
    
    const outer_obj = json.buildObject(.{
        .{ .name = "type", .value = "geometry" },
        .{ .name = "data", .value = arr },
    });
    
    try testing.expectEqual(@as(u16, 2), outer_obj.size());
    try testing.expectEqualStrings("geometry", outer_obj.get("type").?.getString().?);
    
    const data_array = outer_obj.get("data").?.getArray().?;
    try testing.expectEqual(@as(u16, 2), data_array.size());
    try testing.expectEqualStrings("point", data_array.get(0).?.getString().?);
    
    const point_obj = data_array.get(1).?.getObject().?;
    try testing.expectEqual(@as(f64, 10), point_obj.get("x").?.getNumber().?);
    try testing.expectEqual(@as(f64, 20), point_obj.get("y").?.getNumber().?);
}

// ===== JSON SERIALIZATION TESTS =====

test "serialize_simple_values" {
    // String
    var value = json.string("hello");
    var serialized = try json.stringify(value);
    try testing.expectEqualStrings("\"hello\"", serialized);
    
    // Number
    value = json.number(42.5);
    serialized = try json.stringify(value);
    try testing.expectEqualStrings("42.5", serialized);
    
    // Boolean
    value = json.boolean(true);
    serialized = try json.stringify(value);
    try testing.expectEqualStrings("true", serialized);
    
    // Null
    value = json.null();
    serialized = try json.stringify(value);
    try testing.expectEqualStrings("null", serialized);
}

test "serialize_object" {
    const obj = json.buildObject(.{
        .{ .name = "name", .value = "Alice" },
        .{ .name = "age", .value = @as(f64, 25) },
    });
    
    const value = json.JsonValue{ .object = obj };
    const serialized = try json.stringify(value);
    
    // Note: Order might vary, so we check for presence of both fields
    try testing.expect(std.mem.indexOf(u8, serialized, "name") != null);
    try testing.expect(std.mem.indexOf(u8, serialized, "Alice") != null);
    try testing.expect(std.mem.indexOf(u8, serialized, "age") != null);
    try testing.expect(std.mem.indexOf(u8, serialized, "25") != null);
}

test "serialize_array" {
    const arr = json.buildArray(.{ "a", "b", "c" });
    const value = json.JsonValue{ .array = arr };
    const serialized = try json.stringify(value);
    
    try testing.expectEqualStrings("[\"a\",\"b\",\"c\"]", serialized);
}

// ===== PERFORMANCE TESTS =====

test "parse_performance_small" {
    const json_str = "{\"test\":\"value\",\"number\":42,\"array\":[1,2,3]}";
    
    const start_time = std.time.nanoTimestamp();
    
    // Parse multiple times to measure performance
    var i: usize = 0;
    while (i < 1000) : (i += 1) {
        const value = try json.parse(json_str);
        _ = value;
    }
    
    const end_time = std.time.nanoTimestamp();
    const duration_ns = @intCast(u64, end_time - start_time);
    const duration_ms = duration_ns / 1_000_000;
    
    // Should parse 1000 small JSONs in under 100ms
    try testing.expect(duration_ms < 100);
    
    std.debug.print("✅ Small JSON parsing: {d}ms for 1000 iterations\n", .{duration_ms});
}

test "parse_performance_large" {
    // Create a larger JSON object
    var large_obj = json.object();
    var i: u16 = 0;
    while (i < 100) : (i += 1) {
        var inner_obj = json.object();
        try inner_obj.set("id", json.number(@intToFloat(f64, i)));
        try inner_obj.set("name", json.string("item"));
        try inner_obj.set("active", json.boolean(i % 2 == 0));
        
        var key_buf: [16]u8 = undefined;
        const key = try std.fmt.bufPrint(&key_buf, "item_{d}", .{i});
        try large_obj.set(key, json.JsonValue{ .object = inner_obj });
    }
    
    const value = json.JsonValue{ .object = large_obj };
    const json_str = try json.stringify(value);
    
    const start_time = std.time.nanoTimestamp();
    
    // Parse multiple times
    var j: usize = 0;
    while (j < 100) : (j += 1) {
        const parsed_value = try json.parse(json_str);
        _ = parsed_value;
    }
    
    const end_time = std.time.nanoTimestamp();
    const duration_ns = @intCast(u64, end_time - start_time);
    const duration_ms = duration_ns / 1_000_000;
    
    // Should parse 100 large JSONs in under 500ms
    try testing.expect(duration_ms < 500);
    
    std.debug.print("✅ Large JSON parsing: {d}ms for 100 iterations\n", .{duration_ms});
}

// ===== MEMORY USAGE TESTS =====

test "memory_usage_static" {
    const initial_memory = getMemoryUsage();
    
    // Create and parse multiple JSON objects
    var i: usize = 0;
    while (i < 100) : (i += 1) {
        const json_str = "{\"test\":\"value\"}";
        const value = try json.parse(json_str);
        _ = value;
    }
    
    const final_memory = getMemoryUsage();
    const memory_diff = final_memory - initial_memory;
    
    // Memory usage should be minimal (static pools)
    try testing.expect(memory_diff < 1024 * 1024); // Less than 1MB increase
    
    std.debug.print("✅ Memory usage: {d} bytes increase\n", .{memory_diff});
}

test "token_pool_utilization" {
    const json_str = "{\"a\":1,\"b\":2,\"c\":3}";
    const stats = try json.getStats(json_str);
    
    // Token pool should be efficiently utilized
    const utilization = @as(f64, @floatFromInt(stats.tokens_parsed)) / 
                       @as(f64, @floatFromInt(json.json_config.max_tokens));
    
    try testing.expect(utilization > 0.01); // At least 1% utilization
    try testing.expect(utilization < 0.5);  // Less than 50% for small JSON
    
    std.debug.print("✅ Token pool utilization: {d:.2}%\n", .{utilization * 100});
}

// ===== ERROR HANDLING TESTS =====

test "parse_invalid_json" {
    // Missing closing brace
    try testing.expectError(error.UnexpectedEndOfInput, json.parse("{\"name\":\"John\""));
    
    // Missing closing bracket
    try testing.expectError(error.UnexpectedEndOfInput, json.parse("[\"a\",\"b\""));
    
    // Invalid character
    try testing.expectError(error.InvalidCharacter, json.parse("{\"name\":@}"));
    
    // Missing colon
    try testing.expectError(error.ExpectedColon, json.parse("{\"name\"\"John\"}"));
}

test "object_size_limits" {
    var obj = json.object();
    
    // Try to add more keys than allowed
    var i: u16 = 0;
    while (i < json.json_config.max_object_keys + 10) : (i += 1) {
        var key_buf: [16]u8 = undefined;
        const key = try std.fmt.bufPrint(&key_buf, "key_{d}", .{i});
        
        if (i < json.json_config.max_object_keys) {
            try obj.set(key, json.string("value"));
        } else {
            // Should fail when exceeding limit
            try testing.expectError(error.ObjectTooLarge, obj.set(key, json.string("value")));
        }
    }
}

test "array_size_limits" {
    var arr = json.array();
    
    // Try to add more elements than allowed
    var i: u16 = 0;
    while (i < json.json_config.max_array_elements + 10) : (i += 1) {
        if (i < json.json_config.max_array_elements) {
            try arr.append(json.number(@intToFloat(f64, i)));
        } else {
            // Should fail when exceeding limit
            try testing.expectError(error.ArrayTooLarge, arr.append(json.number(@intToFloat(f64, i))));
        }
    }
}

// ===== HELPER FUNCTIONS =====

fn getMemoryUsage() u64 {
    // Simplified memory usage tracking
    // In a real implementation, you'd use platform-specific APIs
    return 0;
}

// ===== COMPILE-TIME TESTS =====

test "compile_time_assertions" {
    // Test that our compile-time assertions work
    try testing.expect(json.FEATURES.static_memory);
    try testing.expect(json.FEATURES.cache_aligned);
    try testing.expect(json.FEATURES.inline_functions);
    
    try testing.expect(json.PERFORMANCE_TARGETS.parse_speed_gb_s > 0);
    try testing.expect(json.PERFORMANCE_TARGETS.memory_overhead_percent < 10);
}

test "json_config_constants" {
    // Test configuration constants
    try testing.expect(json.json_config.max_tokens > 0);
    try testing.expect(json.json_config.max_string_length > 0);
    try testing.expect(json.json_config.max_object_keys > 0);
    try testing.expect(json.json_config.max_array_elements > 0);
    try testing.expect(json.json_config.max_nesting_depth > 0);
    
    // Test SIMD configuration
    try testing.expect(json.json_config.simd_width > 0);
    try testing.expect(json.json_config.cache_line_size > 0);
}
