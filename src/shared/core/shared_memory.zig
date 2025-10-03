// NenDB Shared Memory Coordination for Multi-Process Support
// Implements shared memory segments for inter-process communication

const std = @import("std");
const assert = std.debug.assert;

// Shared memory constants
const SHARED_MEMORY_SIZE: usize = 1024 * 1024; // 1MB shared memory
const SHARED_MEMORY_NAME = "nendb_shared";
const MAX_PROCESSES: usize = 32;
const HEARTBEAT_TIMEOUT_MS: u64 = 5000; // 5 seconds

// Process information structure
const ProcessInfo = struct {
    process_id: u32,
    start_time: i64,
    last_heartbeat: i64,
    lock_type: LockType,
    active: bool,

    const SIZE = 4 + 8 + 8 + 1 + 1; // 22 bytes

    fn serialize(self: *const ProcessInfo, buffer: []u8) void {
        assert(buffer.len >= SIZE);
        var offset: usize = 0;

        std.mem.writeInt(u32, buffer[offset .. offset + 4], self.process_id, .little);
        offset += 4;

        std.mem.writeInt(i64, buffer[offset .. offset + 8], self.start_time, .little);
        offset += 8;

        std.mem.writeInt(i64, buffer[offset .. offset + 8], self.last_heartbeat, .little);
        offset += 8;

        buffer[offset] = @intFromEnum(self.lock_type);
        offset += 1;

        buffer[offset] = if (self.active) 1 else 0;
    }

    fn deserialize(buffer: []const u8) ProcessInfo {
        assert(buffer.len >= SIZE);
        var offset: usize = 0;

        const process_id = std.mem.readInt(u32, buffer[offset .. offset + 4], .little);
        offset += 4;

        const start_time = std.mem.readInt(i64, buffer[offset .. offset + 8], .little);
        offset += 8;

        const last_heartbeat = std.mem.readInt(i64, buffer[offset .. offset + 8], .little);
        offset += 8;

        const lock_type = @as(LockType, @enumFromInt(buffer[offset]));
        offset += 1;

        const active = buffer[offset] != 0;

        return ProcessInfo{
            .process_id = process_id,
            .start_time = start_time,
            .last_heartbeat = last_heartbeat,
            .lock_type = lock_type,
            .active = active,
        };
    }
};

// Lock types for shared memory
const LockType = enum(u8) {
    none = 0,
    shared = 1,
    exclusive = 2,
};

// Shared memory header
const SharedMemoryHeader = struct {
    magic: u32,
    version: u16,
    process_count: u32,
    last_cleanup: i64,
    reserved: [16]u8,

    const SIZE = 4 + 2 + 4 + 8 + 16; // 34 bytes
    const MAGIC: u32 = 0x4E454E53; // 'NENS'
    const VERSION: u16 = 1;

    fn serialize(self: *const SharedMemoryHeader, buffer: []u8) void {
        assert(buffer.len >= SIZE);
        var offset: usize = 0;

        std.mem.writeInt(u32, buffer[offset .. offset + 4], self.magic, .little);
        offset += 4;

        std.mem.writeInt(u16, buffer[offset .. offset + 2], self.version, .little);
        offset += 2;

        std.mem.writeInt(u32, buffer[offset .. offset + 4], self.process_count, .little);
        offset += 4;

        std.mem.writeInt(i64, buffer[offset .. offset + 8], self.last_cleanup, .little);
        offset += 8;

        @memcpy(buffer[offset .. offset + 16], &self.reserved);
    }

    fn deserialize(buffer: []const u8) SharedMemoryHeader {
        assert(buffer.len >= SIZE);
        var offset: usize = 0;

        const magic = std.mem.readInt(u32, buffer[offset .. offset + 4], .little);
        offset += 4;

        const version = std.mem.readInt(u16, buffer[offset .. offset + 2], .little);
        offset += 2;

        const process_count = std.mem.readInt(u32, buffer[offset .. offset + 4], .little);
        offset += 4;

        const last_cleanup = std.mem.readInt(i64, buffer[offset .. offset + 8], .little);
        offset += 8;

        var reserved: [16]u8 = undefined;
        @memcpy(&reserved, buffer[offset .. offset + 16]);

        return SharedMemoryHeader{
            .magic = magic,
            .version = version,
            .process_count = process_count,
            .last_cleanup = last_cleanup,
            .reserved = reserved,
        };
    }
};

// Shared memory coordinator
pub const SharedMemoryCoordinator = struct {
    shared_memory: ?[]u8 = null,
    process_slot: ?usize = null,
    process_id: u32,
    start_time: i64,
    allocator: std.mem.Allocator,

    // Statistics
    stats: SharedMemoryStats = SharedMemoryStats{},

    pub const SharedMemoryStats = struct {
        processes_registered: u32 = 0,
        processes_cleaned: u32 = 0,
        heartbeats_sent: u64 = 0,
        coordination_errors: u32 = 0,
    };

    pub fn init(allocator: std.mem.Allocator) !SharedMemoryCoordinator {
        const process_id = std.os.linux.getpid();
        const start_time = std.time.timestamp();

        return SharedMemoryCoordinator{
            .process_id = @intCast(process_id),
            .start_time = start_time,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *SharedMemoryCoordinator) void {
        if (self.process_slot) |slot| {
            self.unregisterProcess(slot) catch {};
        }

        if (self.shared_memory) |mem| {
            self.allocator.free(mem);
        }
    }

    /// Attach to shared memory segment
    pub fn attach(self: *SharedMemoryCoordinator) !void {
        if (self.shared_memory != null) return;

        // Try to open existing shared memory
        const shm_fd = std.os.memfd_create(SHARED_MEMORY_NAME, 0) catch |e| switch (e) {
            error.FileNotFound => {
                // Create new shared memory segment
                return self.createSharedMemory();
            },
            else => return e,
        };
        defer std.os.close(shm_fd);

        // Map shared memory
        const memory = try std.os.mmap(null, SHARED_MEMORY_SIZE, std.os.PROT.READ | std.os.PROT.WRITE, std.os.MAP.SHARED, shm_fd, 0);

        self.shared_memory = memory;

        // Initialize if this is the first process
        try self.initializeIfNeeded();
    }

    /// Create new shared memory segment
    fn createSharedMemory(self: *SharedMemoryCoordinator) !void {
        const shm_fd = try std.os.memfd_create(SHARED_MEMORY_NAME, 0);
        defer std.os.close(shm_fd);

        // Set size
        try std.os.ftruncate(shm_fd, SHARED_MEMORY_SIZE);

        // Map shared memory
        const memory = try std.os.mmap(null, SHARED_MEMORY_SIZE, std.os.PROT.READ | std.os.PROT.WRITE, std.os.MAP.SHARED, shm_fd, 0);

        self.shared_memory = memory;

        // Initialize the shared memory
        try self.initializeSharedMemory();
    }

    /// Initialize shared memory if needed
    fn initializeIfNeeded(self: *SharedMemoryCoordinator) !void {
        const memory = self.shared_memory orelse return;

        // Check if already initialized
        const header = SharedMemoryHeader.deserialize(memory[0..SharedMemoryHeader.SIZE]);
        if (header.magic == SharedMemoryHeader.MAGIC) {
            return; // Already initialized
        }

        // Initialize
        try self.initializeSharedMemory();
    }

    /// Initialize shared memory with header
    fn initializeSharedMemory(self: *SharedMemoryCoordinator) !void {
        const memory = self.shared_memory orelse return;

        // Clear memory
        @memset(memory, 0);

        // Write header
        const header = SharedMemoryHeader{
            .magic = SharedMemoryHeader.MAGIC,
            .version = SharedMemoryHeader.VERSION,
            .process_count = 0,
            .last_cleanup = std.time.timestamp(),
            .reserved = [_]u8{0} ** 16,
        };

        header.serialize(memory[0..SharedMemoryHeader.SIZE]);
    }

    /// Register current process
    pub fn registerProcess(self: *SharedMemoryCoordinator, lock_type: LockType) !usize {
        if (self.shared_memory == null) {
            try self.attach();
        }

        const memory = self.shared_memory orelse return error.NoSharedMemory;

        // Find available slot
        const slot = try self.findAvailableSlot();

        // Register process
        const process_info = ProcessInfo{
            .process_id = self.process_id,
            .start_time = self.start_time,
            .last_heartbeat = std.time.timestamp(),
            .lock_type = lock_type,
            .active = true,
        };

        const slot_offset = SharedMemoryHeader.SIZE + (slot * ProcessInfo.SIZE);
        process_info.serialize(memory[slot_offset .. slot_offset + ProcessInfo.SIZE]);

        // Update process count
        const header = SharedMemoryHeader.deserialize(memory[0..SharedMemoryHeader.SIZE]);
        var new_header = header;
        new_header.process_count += 1;
        new_header.serialize(memory[0..SharedMemoryHeader.SIZE]);

        self.process_slot = slot;
        self.stats.processes_registered += 1;

        return slot;
    }

    /// Unregister current process
    pub fn unregisterProcess(self: *SharedMemoryCoordinator, slot: usize) !void {
        if (self.shared_memory == null) return;

        const memory = self.shared_memory orelse return;

        // Clear process slot
        const slot_offset = SharedMemoryHeader.SIZE + (slot * ProcessInfo.SIZE);
        @memset(memory[slot_offset .. slot_offset + ProcessInfo.SIZE], 0);

        // Update process count
        const header = SharedMemoryHeader.deserialize(memory[0..SharedMemoryHeader.SIZE]);
        var new_header = header;
        if (new_header.process_count > 0) {
            new_header.process_count -= 1;
        }
        new_header.serialize(memory[0..SharedMemoryHeader.SIZE]);

        self.process_slot = null;
    }

    /// Send heartbeat
    pub fn sendHeartbeat(self: *SharedMemoryCoordinator) !void {
        if (self.shared_memory == null or self.process_slot == null) return;

        const memory = self.shared_memory orelse return;
        const slot = self.process_slot.?;

        const slot_offset = SharedMemoryHeader.SIZE + (slot * ProcessInfo.SIZE);
        const process_info = ProcessInfo.deserialize(memory[slot_offset .. slot_offset + ProcessInfo.SIZE]);

        var updated_info = process_info;
        updated_info.last_heartbeat = std.time.timestamp();
        updated_info.serialize(memory[slot_offset .. slot_offset + ProcessInfo.SIZE]);

        self.stats.heartbeats_sent += 1;
    }

    /// Get list of active processes
    pub fn getActiveProcesses(self: *SharedMemoryCoordinator) ![]ProcessInfo {
        if (self.shared_memory == null) return &[_]ProcessInfo{};

        const memory = self.shared_memory orelse return &[_]ProcessInfo{};
        _ = SharedMemoryHeader.deserialize(memory[0..SharedMemoryHeader.SIZE]);

        var processes = std.ArrayList(ProcessInfo).init(self.allocator);
        defer processes.deinit();

        const current_time = std.time.timestamp();

        for (0..MAX_PROCESSES) |i| {
            const slot_offset = SharedMemoryHeader.SIZE + (i * ProcessInfo.SIZE);
            const process_info = ProcessInfo.deserialize(memory[slot_offset .. slot_offset + ProcessInfo.SIZE]);

            if (process_info.active and process_info.process_id != 0) {
                // Check if process is still alive (heartbeat timeout)
                const time_since_heartbeat = current_time - process_info.last_heartbeat;
                if (time_since_heartbeat < HEARTBEAT_TIMEOUT_MS / 1000) {
                    try processes.append(process_info);
                }
            }
        }

        return processes.toOwnedSlice();
    }

    /// Clean up dead processes
    pub fn cleanupDeadProcesses(self: *SharedMemoryCoordinator) !u32 {
        if (self.shared_memory == null) return 0;

        const memory = self.shared_memory orelse return 0;
        const current_time = std.time.timestamp();
        var cleaned_count: u32 = 0;

        for (0..MAX_PROCESSES) |i| {
            const slot_offset = SharedMemoryHeader.SIZE + (i * ProcessInfo.SIZE);
            const process_info = ProcessInfo.deserialize(memory[slot_offset .. slot_offset + ProcessInfo.SIZE]);

            if (process_info.active and process_info.process_id != 0) {
                const time_since_heartbeat = current_time - process_info.last_heartbeat;
                if (time_since_heartbeat >= HEARTBEAT_TIMEOUT_MS / 1000) {
                    // Process is dead, clean up
                    @memset(memory[slot_offset .. slot_offset + ProcessInfo.SIZE], 0);
                    cleaned_count += 1;
                }
            }
        }

        // Update process count
        if (cleaned_count > 0) {
            const header = SharedMemoryHeader.deserialize(memory[0..SharedMemoryHeader.SIZE]);
            var new_header = header;
            if (new_header.process_count >= cleaned_count) {
                new_header.process_count -= cleaned_count;
            } else {
                new_header.process_count = 0;
            }
            new_header.last_cleanup = current_time;
            new_header.serialize(memory[0..SharedMemoryHeader.SIZE]);
        }

        self.stats.processes_cleaned += cleaned_count;
        return cleaned_count;
    }

    /// Find available process slot
    fn findAvailableSlot(self: *SharedMemoryCoordinator) !usize {
        const memory = self.shared_memory orelse return error.NoSharedMemory;

        for (0..MAX_PROCESSES) |i| {
            const slot_offset = SharedMemoryHeader.SIZE + (i * ProcessInfo.SIZE);
            const process_info = ProcessInfo.deserialize(memory[slot_offset .. slot_offset + ProcessInfo.SIZE]);

            if (!process_info.active or process_info.process_id == 0) {
                return i;
            }
        }

        return error.NoAvailableSlots;
    }

    /// Check if we have exclusive access
    pub fn hasExclusiveAccess(self: *SharedMemoryCoordinator) !bool {
        const processes = try self.getActiveProcesses();
        defer self.allocator.free(processes);

        for (processes) |process| {
            if (process.process_id != self.process_id and process.lock_type == .exclusive) {
                return false;
            }
        }

        return true;
    }

    /// Get statistics
    pub fn getStats(self: *const SharedMemoryCoordinator) SharedMemoryStats {
        return self.stats;
    }
};

// Test utilities
pub const SharedMemoryTester = struct {
    pub fn testSharedMemory(allocator: std.mem.Allocator) !void {
        var coordinator = try SharedMemoryCoordinator.init(allocator);
        defer coordinator.deinit();

        // Test 1: Attach to shared memory
        try coordinator.attach();

        // Test 2: Register process
        const slot = try coordinator.registerProcess(.exclusive);
        assert(slot < MAX_PROCESSES);

        // Test 3: Send heartbeat
        try coordinator.sendHeartbeat();

        // Test 4: Get active processes
        const processes = try coordinator.getActiveProcesses();
        defer allocator.free(processes);
        assert(processes.len >= 1);

        // Test 5: Unregister process
        try coordinator.unregisterProcess(slot);

        std.debug.print("✅ Shared memory tests passed\n", .{});
    }
};
