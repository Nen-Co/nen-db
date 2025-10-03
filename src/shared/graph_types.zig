// Nen Shared Graph Types (for embedded & distributed DB)
// See The NenWay.instructions.md for style and memory rules.

const std = @import("std");

/// Node representation (data-oriented, static memory)
pub const Node = struct {
    id: u64,
    label: []const u8,
    group: u8,
    // Add more fields as needed (properties, etc.)
};

/// Edge representation (data-oriented, static memory)
pub const Edge = struct {
    src: u64,
    dst: u64,
    label: []const u8,
    // Add more fields as needed (properties, etc.)
};

/// Batch for processing nodes/edges (static, fixed-size)
pub fn Batch(comptime T: type, comptime N: usize) type {
    return struct {
        items: [N]T,
        count: usize,

        pub fn init() Batch(T, N) {
            return Batch(T, N){ .items = undefined, .count = 0 };
        }

        pub fn push(self: *Batch(T, N), item: T) !void {
            if (self.count >= N) return error.BatchFull;
            self.items[self.count] = item;
            self.count += 1;
        }
    };
}
