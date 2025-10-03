// NenDB File Locking for Multi-Process Support
// Implements advisory file locking to prevent multiple processes from accessing the same database

const std = @import("std");
const assert = std.debug.assert;

// File locking constants
const LOCK_FILE_SUFFIX = ".lock";
const LOCK_TIMEOUT_MS = 5000; // 5 seconds
const LOCK_RETRY_INTERVAL_MS = 100; // 100ms
const MAX_LOCK_RETRIES = 50; // 5 seconds total

// Lock types for different operations
pub const LockType = enum {
    shared, // Multiple readers allowed
    exclusive, // Single writer only
};

// Lock acquisition result
pub const LockResult = enum {
    acquired,
    timeout,
    failed,
};

// File lock manager for multi-process coordination
pub const FileLockManager = struct {
    lock_file: ?std.fs.File = null,
    lock_path: []const u8,
    lock_type: LockType,
    acquired: bool = false,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, data_dir: []const u8) !FileLockManager {
        const lock_path = try std.fmt.allocPrint(allocator, "{s}{s}", .{ data_dir, LOCK_FILE_SUFFIX });

        return FileLockManager{
            .lock_path = lock_path,
            .lock_type = .exclusive, // Default to exclusive
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *FileLockManager) void {
        if (self.acquired) {
            self.releaseLock() catch {};
        }

        if (self.lock_file) |*f| {
            f.close();
        }

        self.allocator.free(self.lock_path);
    }

    /// Acquire a file lock with timeout
    pub fn acquireLock(self: *FileLockManager, lock_type: LockType) !LockResult {
        assert(!self.acquired);

        self.lock_type = lock_type;

        // Try to open/create the lock file
        self.lock_file = std.fs.cwd().createFile(self.lock_path, .{ .read = true, .truncate = false }) catch |e| switch (e) {
            error.FileNotFound => {
                // Create parent directory if it doesn't exist
                const dir_path = std.fs.path.dirname(self.lock_path) orelse ".";
                std.fs.cwd().makeDir(dir_path) catch |dir_err| switch (dir_err) {
                    error.PathAlreadyExists => {},
                    else => return dir_err,
                };

                self.lock_file = try std.fs.cwd().createFile(self.lock_path, .{ .read = true, .truncate = false });
            },
            else => return e,
        };

        // Try to acquire lock with retries
        var retries: u32 = 0;
        while (retries < MAX_LOCK_RETRIES) {
            const lock_result = self.tryLock();

            switch (lock_result) {
                .acquired => {
                    self.acquired = true;
                    return .acquired;
                },
                .timeout => {
                    retries += 1;
                    std.time.sleep(LOCK_RETRY_INTERVAL_MS * std.time.ns_per_ms);
                },
                .failed => return .failed,
            }
        }

        return .timeout;
    }

    /// Try to acquire lock without blocking
    fn tryLock(self: *FileLockManager) LockResult {
        const file = self.lock_file orelse return .failed;

        // Use flock for advisory locking
        const lock_cmd = switch (self.lock_type) {
            .shared => std.os.LOCK.SH,
            .exclusive => std.os.LOCK.EX,
        };

        const result = std.os.flock(file.handle, lock_cmd | std.os.LOCK.NB);
        return switch (result) {
            .success => .acquired,
            .errno => |err| switch (err) {
                .AGAIN, .WOULDBLOCK => .timeout,
                else => .failed,
            },
        };
    }

    /// Release the file lock
    pub fn releaseLock(self: *FileLockManager) !void {
        if (!self.acquired or self.lock_file == null) return;

        const file = self.lock_file.?;
        _ = std.os.flock(file.handle, std.os.LOCK.UN);

        self.acquired = false;
    }

    /// Check if lock is currently held
    pub fn isLocked(self: *const FileLockManager) bool {
        return self.acquired;
    }

    /// Get lock file path
    pub fn getLockPath(self: *const FileLockManager) []const u8 {
        return self.lock_path;
    }

    /// Check if another process is holding the lock
    pub fn isLockedByOther(self: *FileLockManager) !bool {
        if (self.lock_file == null) {
            self.lock_file = std.fs.cwd().openFile(self.lock_path, .{}) catch |e| switch (e) {
                error.FileNotFound => return false, // No lock file means no lock
                else => return e,
            };
        }

        const result = self.tryLock();
        return switch (result) {
            .acquired => {
                // We got the lock, so no one else had it
                _ = std.os.flock(self.lock_file.?.handle, std.os.LOCK.UN);
                return false;
            },
            .timeout => true, // Someone else has the lock
            .failed => return .failed,
        };
    }
};

// Process coordination utilities
pub const ProcessCoordinator = struct {
    lock_manager: FileLockManager,
    process_id: u32,
    start_time: i64,

    pub fn init(allocator: std.mem.Allocator, data_dir: []const u8) !ProcessCoordinator {
        const lock_manager = try FileLockManager.init(allocator, data_dir);
        const process_id = std.os.linux.getpid();
        const start_time = std.time.timestamp();

        return ProcessCoordinator{
            .lock_manager = lock_manager,
            .process_id = @intCast(process_id),
            .start_time = start_time,
        };
    }

    pub fn deinit(self: *ProcessCoordinator) void {
        self.lock_manager.deinit();
    }

    /// Acquire exclusive access to the database
    pub fn acquireExclusiveAccess(self: *ProcessCoordinator) !LockResult {
        return self.lock_manager.acquireLock(.exclusive);
    }

    /// Acquire shared access to the database
    pub fn acquireSharedAccess(self: *ProcessCoordinator) !LockResult {
        return self.lock_manager.acquireLock(.shared);
    }

    /// Release database access
    pub fn releaseAccess(self: *ProcessCoordinator) !void {
        try self.lock_manager.releaseLock();
    }

    /// Check if we have exclusive access
    pub fn hasExclusiveAccess(self: *const ProcessCoordinator) bool {
        return self.lock_manager.isLocked() and self.lock_manager.lock_type == .exclusive;
    }

    /// Check if we have shared access
    pub fn hasSharedAccess(self: *const ProcessCoordinator) bool {
        return self.lock_manager.isLocked() and self.lock_manager.lock_type == .shared;
    }

    /// Get process information
    pub fn getProcessInfo(self: *const ProcessCoordinator) struct { process_id: u32, start_time: i64 } {
        return .{
            .process_id = self.process_id,
            .start_time = self.start_time,
        };
    }
};

// Test utilities for file locking
pub const FileLockTester = struct {
    pub fn testFileLocking(allocator: std.mem.Allocator) !void {
        const test_dir = "test_locks";
        defer std.fs.cwd().deleteTree(test_dir) catch {};

        // Test 1: Basic lock acquisition
        var lock_manager = try FileLockManager.init(allocator, test_dir);
        defer lock_manager.deinit();

        const result = try lock_manager.acquireLock(.exclusive);
        assert(result == .acquired);
        assert(lock_manager.isLocked());

        try lock_manager.releaseLock();
        assert(!lock_manager.isLocked());

        // Test 2: Process coordinator
        var coordinator = try ProcessCoordinator.init(allocator, test_dir);
        defer coordinator.deinit();

        const access_result = try coordinator.acquireExclusiveAccess();
        assert(access_result == .acquired);
        assert(coordinator.hasExclusiveAccess());

        try coordinator.releaseAccess();
        assert(!coordinator.hasExclusiveAccess());

        std.debug.print("✅ File locking tests passed\n", .{});
    }
};
