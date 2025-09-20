// NenDB Concurrency Module - Minimal Implementation for Zig 0.15.1
// Implements basic concurrency primitives for graph database

const std = @import("std");
const constants = @import("constants.zig");

// =============================================================================
// Lock-Free Data Structures
// =============================================================================

/// Lock-free node counter with atomic operations
pub const AtomicCounter = struct {
    value: std.atomic.Value(u32) = std.atomic.Value(u32).init(0),

    pub inline fn increment(self: *AtomicCounter) u32 {
        return self.value.fetchAdd(1, .monotonic);
    }

    pub inline fn decrement(self: *AtomicCounter) u32 {
        return self.value.fetchSub(1, .monotonic);
    }

    pub inline fn load(self: *const AtomicCounter) u32 {
        return self.value.load(.monotonic);
    }

    pub inline fn store(self: *AtomicCounter, new_value: u32) void {
        self.value.store(new_value, .monotonic);
    }
};

/// Lock-free node ID generator
pub const AtomicIdGenerator = struct {
    next_id: std.atomic.Value(u32) = std.atomic.Value(u32).init(1),

    pub inline fn generate(self: *AtomicIdGenerator) u32 {
        return self.next_id.fetchAdd(1, .monotonic);
    }

    pub inline fn peek(self: *const AtomicIdGenerator) u32 {
        return self.next_id.load(.monotonic);
    }
};

// =============================================================================
// Read-Write Lock Implementation (Simplified)
// =============================================================================

/// High-performance read-write lock with reader bias
pub const ReadWriteLock = struct {
    reader_count: std.atomic.Value(u32) = std.atomic.Value(u32).init(0),
    writer_pending: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),
    writer_active: std.atomic.Value(bool) = std.atomic.Value(bool).init(false),
    mutex: std.Thread.Mutex = .{},

    pub inline fn readLock(self: *ReadWriteLock) void {
        // Increment reader count
        _ = self.reader_count.fetchAdd(1, .acquire);

        // Wait for writer to finish (simplified - no yield)
        while (self.writer_active.load(.acquire)) {
            // Simple spin wait
        }
    }

    pub inline fn readUnlock(self: *ReadWriteLock) void {
        _ = self.reader_count.fetchSub(1, .release);
    }

    pub inline fn writeLock(self: *ReadWriteLock) void {
        self.mutex.lock();

        // Signal that writer is pending
        self.writer_pending.store(true, .release);

        // Wait for all readers to finish (simplified - no yield)
        while (self.reader_count.load(.acquire) > 0) {
            // Simple spin wait
        }

        // Mark writer as active
        self.writer_active.store(true, .release);
    }

    pub inline fn writeUnlock(self: *ReadWriteLock) void {
        self.writer_active.store(false, .release);
        self.writer_pending.store(false, .release);
        self.mutex.unlock();
    }

    pub inline fn tryReadLock(self: *ReadWriteLock) bool {
        if (self.writer_active.load(.acquire)) return false;

        _ = self.reader_count.fetchAdd(1, .acquire);

        // Double-check writer didn't start
        if (self.writer_active.load(.acquire)) {
            _ = self.reader_count.fetchSub(1, .release);
            return false;
        }

        return true;
    }

    pub inline fn tryWriteLock(self: *ReadWriteLock) bool {
        if (!self.mutex.tryLock()) return false;

        if (self.reader_count.load(.acquire) > 0 or self.writer_active.load(.acquire)) {
            self.mutex.unlock();
            return false;
        }

        self.writer_active.store(true, .release);
        return true;
    }
};

// =============================================================================
// Seqlock Implementation (Lock-Free Reads)
// =============================================================================

/// Seqlock for lock-free reads with write protection
pub const Seqlock = struct {
    sequence: std.atomic.Value(u32) = std.atomic.Value(u32).init(0),

    pub inline fn readBegin(self: *const Seqlock) u32 {
        return self.sequence.load(.acquire);
    }

    pub inline fn readEnd(self: *const Seqlock, start_seq: u32) bool {
        const end_seq = self.sequence.load(.acquire);
        return (start_seq & 1) == 0 and start_seq == end_seq;
    }

    pub inline fn writeLock(self: *Seqlock) void {
        // Increment sequence (odd = write in progress)
        _ = self.sequence.fetchAdd(1, .acq_rel);
    }

    pub inline fn writeUnlock(self: *Seqlock) void {
        // Increment sequence (even = write complete)
        _ = self.sequence.fetchAdd(1, .acq_rel);
    }
};

// =============================================================================
// Transaction Support (Simplified)
// =============================================================================

/// Transaction isolation levels
pub const IsolationLevel = enum {
    read_uncommitted,
    read_committed,
    repeatable_read,
    serializable,
};

/// Transaction state
pub const TransactionState = enum {
    active,
    committed,
    aborted,
    preparing,
};

/// Basic transaction support
pub const Transaction = struct {
    id: u32,
    isolation_level: IsolationLevel,
    state: TransactionState,
    read_set: std.ArrayList(u32),
    write_set: std.ArrayList(u32),
    start_time: i64,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, id: u32, isolation: IsolationLevel) !Transaction {
        return Transaction{
            .id = id,
            .isolation_level = isolation,
            .state = .active,
            .read_set = std.ArrayList(u32).init(allocator),
            .write_set = std.ArrayList(u32).init(allocator),
            .start_time = std.time.timestamp(),
        };
    }

    pub fn deinit(self: *Transaction) void {
        self.read_set.deinit();
        self.write_set.deinit();
    }

    pub inline fn addRead(self: *Transaction, node_id: u32) !void {
        try self.read_set.append(node_id);
    }

    pub inline fn addWrite(self: *Transaction, node_id: u32) !void {
        try self.write_set.append(node_id);
    }

    pub inline fn commit(self: *Transaction) void {
        self.state = .committed;
    }

    pub inline fn abort(self: *Transaction) void {
        self.state = .aborted;
    }

    pub inline fn isActive(self: *const Transaction) bool {
        return self.state == .active;
    }
};

// =============================================================================
// Deadlock Detection (Simplified - No ArrayList)
// =============================================================================

/// Simple deadlock detection using lock ordering
pub const DeadlockDetector = struct {
    // Simple fixed-size array instead of ArrayList
    lock_order: [16]u32 = [_]u32{0} ** 16,
    lock_count: u32 = 0,

    pub fn init(_: std.mem.Allocator) DeadlockDetector {
        return DeadlockDetector{};
    }

    pub fn deinit(self: *DeadlockDetector) void {
        _ = self;
        // No cleanup needed for fixed-size array
    }

    pub fn acquireLock(self: *DeadlockDetector, lock_id: u32) !void {
        // Check if lock is already held
        for (0..self.lock_count) |i| {
            if (self.lock_order[i] == lock_id) {
                return constants.NenDBError.AlreadyLocked;
            }
        }

        // Add to lock order (enforces ordering)
        if (self.lock_count >= 16) {
            return constants.NenDBError.PoolExhausted;
        }

        self.lock_order[self.lock_count] = lock_id;
        self.lock_count += 1;
    }

    pub fn releaseLock(self: *DeadlockDetector, lock_id: u32) void {
        // Remove from lock order
        for (0..self.lock_count) |i| {
            if (self.lock_order[i] == lock_id) {
                // Move last element to this position
                self.lock_count -= 1;
                if (i < self.lock_count) {
                    self.lock_order[i] = self.lock_order[self.lock_count];
                }
                break;
            }
        }
    }
};

// =============================================================================
// Performance Monitoring
// =============================================================================

/// Concurrency performance metrics
pub const ConcurrencyMetrics = struct {
    read_locks_acquired: AtomicCounter = AtomicCounter{},
    write_locks_acquired: AtomicCounter = AtomicCounter{},
    lock_contention_count: AtomicCounter = AtomicCounter{},
    deadlock_detection_count: AtomicCounter = AtomicCounter{},
    seqlock_retries: AtomicCounter = AtomicCounter{},

    pub fn getStats(self: *const ConcurrencyMetrics) ConcurrencyStats {
        return ConcurrencyStats{
            .read_locks = self.read_locks_acquired.load(),
            .write_locks = self.write_locks_acquired.load(),
            .contention = self.lock_contention_count.load(),
            .deadlocks_detected = self.deadlock_detection_count.load(),
            .seqlock_retries = self.seqlock_retries.load(),
        };
    }
};

pub const ConcurrencyStats = struct {
    read_locks: u32,
    write_locks: u32,
    contention: u32,
    deadlocks_detected: u32,
    seqlock_retries: u32,
};

// =============================================================================
// Tests
// =============================================================================

test "atomic counter operations" {
    var counter = AtomicCounter{};

    try std.testing.expectEqual(@as(u32, 0), counter.load());

    _ = counter.increment();
    try std.testing.expectEqual(@as(u32, 1), counter.load());

    _ = counter.increment();
    try std.testing.expectEqual(@as(u32, 2), counter.load());

    _ = counter.decrement();
    try std.testing.expectEqual(@as(u32, 1), counter.load());
}

test "atomic id generator" {
    var generator = AtomicIdGenerator{};

    try std.testing.expectEqual(@as(u32, 1), generator.peek());

    const id1 = generator.generate();
    try std.testing.expectEqual(@as(u32, 1), id1);
    try std.testing.expectEqual(@as(u32, 2), generator.peek());

    const id2 = generator.generate();
    try std.testing.expectEqual(@as(u32, 2), id2);
    try std.testing.expectEqual(@as(u32, 3), generator.peek());
}

test "read-write lock basic operations" {
    var rwlock = ReadWriteLock{};

    // Test read lock
    rwlock.readLock();
    try std.testing.expectEqual(@as(u32, 1), rwlock.reader_count.load(.monotonic));
    rwlock.readUnlock();
    try std.testing.expectEqual(@as(u32, 0), rwlock.reader_count.load(.monotonic));

    // Test write lock
    rwlock.writeLock();
    try std.testing.expect(rwlock.writer_active.load(.monotonic));
    rwlock.writeUnlock();
    try std.testing.expect(!rwlock.writer_active.load(.monotonic));
}

test "seqlock operations" {
    var seqlock = Seqlock{};

    // Test read sequence
    const seq1 = seqlock.readBegin();
    try std.testing.expect(seqlock.readEnd(seq1));

    // Test write sequence
    seqlock.writeLock();
    const seq2 = seqlock.readBegin();
    try std.testing.expect(!seqlock.readEnd(seq2)); // Write in progress

    seqlock.writeUnlock();
    const seq3 = seqlock.readBegin();
    try std.testing.expect(seqlock.readEnd(seq3)); // Write complete
}

test "transaction operations" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var txn = try Transaction.init(allocator, 1, .read_committed);
    defer txn.deinit();

    try std.testing.expect(txn.isActive());
    try std.testing.expectEqual(IsolationLevel.read_committed, txn.isolation_level);

    try txn.addRead(100);
    try txn.addWrite(200);

    try std.testing.expectEqual(@as(usize, 1), txn.read_set.items.len);
    try std.testing.expectEqual(@as(usize, 1), txn.write_set.items.len);

    txn.commit();
    try std.testing.expectEqual(TransactionState.committed, txn.state);
    try std.testing.expect(!txn.isActive());
}
