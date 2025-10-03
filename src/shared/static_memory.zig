// Nen Shared Static Memory Utilities
// For static arena/fixed buffer management (NenWay)

const std = @import("std");

/// FixedBufferArena for static allocation (no dynamic alloc after init)
pub const FixedBufferArena = struct {
    buffer: []u8,
    used: usize,

    pub fn init(buf: []u8) FixedBufferArena {
        return FixedBufferArena{ .buffer = buf, .used = 0 };
    }

    pub fn alloc(self: *FixedBufferArena, n: usize) ![]u8 {
        if (self.used + n > self.buffer.len) return error.ArenaFull;
        const out = self.buffer[self.used .. self.used + n];
        self.used += n;
        return out;
    }

    pub fn reset(self: *FixedBufferArena) void {
        self.used = 0;
    }
};
