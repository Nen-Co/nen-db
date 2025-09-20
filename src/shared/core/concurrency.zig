//! Core Concurrency Primitives for NenDB
//!
//! Provides basic concurrency control for the core database operations.

const std = @import("std");
const constants = @import("../concurrency/constants.zig");

// Re-export concurrency types from shared
pub const ReadWriteLock = @import("../concurrency/concurrency.zig").ReadWriteLock;
pub const AtomicCounter = @import("../concurrency/concurrency.zig").AtomicCounter;
pub const AtomicIdGenerator = @import("../concurrency/concurrency.zig").AtomicIdGenerator;
pub const Seqlock = @import("../concurrency/concurrency.zig").Seqlock;
pub const DeadlockDetector = @import("../concurrency/concurrency.zig").DeadlockDetector;
pub const Transaction = @import("../concurrency/concurrency.zig").Transaction;
pub const IsolationLevel = @import("../concurrency/concurrency.zig").IsolationLevel;
pub const ConcurrencyMetrics = @import("../concurrency/concurrency.zig").ConcurrencyMetrics;

// Core concurrency manager
pub const CoreConcurrencyManager = struct {
    allocator: std.mem.Allocator,
    rwlock: ReadWriteLock,
    node_counter: AtomicCounter,
    edge_counter: AtomicCounter,
    node_id_generator: AtomicIdGenerator,
    edge_id_generator: AtomicIdGenerator,
    metrics: ConcurrencyMetrics,
    deadlock_detector: DeadlockDetector,

    pub fn init(allocator: std.mem.Allocator) @This() {
        return CoreConcurrencyManager{
            .allocator = allocator,
            .rwlock = ReadWriteLock{},
            .node_counter = AtomicCounter{},
            .edge_counter = AtomicCounter{},
            .node_id_generator = AtomicIdGenerator{},
            .edge_id_generator = AtomicIdGenerator{},
            .metrics = ConcurrencyMetrics{},
            .deadlock_detector = DeadlockDetector.init(allocator),
        };
    }

    pub fn deinit(self: *@This()) void {
        self.deadlock_detector.deinit();
    }

    // Core operations with concurrency control
    pub fn acquireReadLock(self: *@This()) !void {
        try self.rwlock.acquireRead();
        self.metrics.read_locks_acquired += 1;
    }

    pub fn releaseReadLock(self: *@This()) void {
        self.rwlock.releaseRead();
        self.metrics.read_locks_released += 1;
    }

    pub fn acquireWriteLock(self: *@This()) !void {
        try self.rwlock.acquireWrite();
        self.metrics.write_locks_acquired += 1;
    }

    pub fn releaseWriteLock(self: *@This()) void {
        self.rwlock.releaseWrite();
        self.metrics.write_locks_released += 1;
    }

    pub fn generateNodeId(self: *@This()) u32 {
        return self.node_id_generator.generate();
    }

    pub fn generateEdgeId(self: *@This()) u32 {
        return self.edge_id_generator.generate();
    }

    pub fn incrementNodeCounter(self: *@This()) u32 {
        return self.node_counter.increment();
    }

    pub fn incrementEdgeCounter(self: *@This()) u32 {
        return self.edge_counter.increment();
    }

    pub fn getNodeCount(self: *@This()) u32 {
        return self.node_counter.load();
    }

    pub fn getEdgeCount(self: *@This()) u32 {
        return self.edge_counter.load();
    }

    pub fn getMetrics(self: *@This()) ConcurrencyMetrics {
        return self.metrics;
    }

    pub fn beginTransaction(self: *@This(), isolation: IsolationLevel) !Transaction {
        return Transaction.init(self.allocator, self.generateNodeId(), isolation);
    }
};
