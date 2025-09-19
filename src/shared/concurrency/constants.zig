//! Concurrency Constants for NenDB
//! 
//! Defines constants used in concurrency control, locking,
//! and thread synchronization.

const std = @import("std");

// Lock timeout constants
pub const DEFAULT_LOCK_TIMEOUT_MS = 1000;
pub const MAX_LOCK_TIMEOUT_MS = 30000;
pub const MIN_LOCK_TIMEOUT_MS = 10;

// Retry constants
pub const DEFAULT_MAX_RETRIES = 3;
pub const MAX_MAX_RETRIES = 100;
pub const DEFAULT_RETRY_DELAY_MS = 10;

// Thread pool constants
pub const DEFAULT_THREAD_POOL_SIZE = 4;
pub const MAX_THREAD_POOL_SIZE = 64;
pub const MIN_THREAD_POOL_SIZE = 1;

// Deadlock detection constants
pub const DEFAULT_DEADLOCK_TIMEOUT_MS = 5000;
pub const MAX_DEADLOCK_TIMEOUT_MS = 60000;
pub const DEADLOCK_DETECTION_INTERVAL_MS = 100;

// Transaction constants
pub const DEFAULT_TRANSACTION_TIMEOUT_MS = 10000;
pub const MAX_TRANSACTION_TIMEOUT_MS = 300000;
pub const MIN_TRANSACTION_TIMEOUT_MS = 100;

// Memory ordering constants
pub const DEFAULT_MEMORY_ORDERING = std.builtin.AtomicOrder.monotonic;
pub const ACQUIRE_MEMORY_ORDERING = std.builtin.AtomicOrder.acquire;
pub const RELEASE_MEMORY_ORDERING = std.builtin.AtomicOrder.release;

// Lock types
pub const LockType = enum {
    read,
    write,
    exclusive,
    shared,
};

// Lock states
pub const LockState = enum {
    unlocked,
    locked,
    waiting,
    deadlocked,
};

// Transaction states
pub const TransactionState = enum {
    active,
    committed,
    aborted,
    prepared,
};

// Isolation levels
pub const IsolationLevel = enum {
    read_uncommitted,
    read_committed,
    repeatable_read,
    serializable,
};

// Error codes
pub const ConcurrencyError = error{
    LockTimeout,
    DeadlockDetected,
    TransactionAborted,
    InvalidLockState,
    InvalidTransactionState,
    LockNotHeld,
    LockAlreadyHeld,
    InvalidIsolationLevel,
    TransactionTimeout,
    ConcurrencyLimitExceeded,
};

// Utility functions
pub fn isValidLockTimeout(timeout_ms: u32) bool {
    return timeout_ms >= MIN_LOCK_TIMEOUT_MS and timeout_ms <= MAX_LOCK_TIMEOUT_MS;
}

pub fn isValidThreadPoolSize(size: u32) bool {
    return size >= MIN_THREAD_POOL_SIZE and size <= MAX_THREAD_POOL_SIZE;
}

pub fn isValidTransactionTimeout(timeout_ms: u32) bool {
    return timeout_ms >= MIN_TRANSACTION_TIMEOUT_MS and timeout_ms <= MAX_TRANSACTION_TIMEOUT_MS;
}

pub fn isValidMaxRetries(retries: u32) bool {
    return retries <= MAX_MAX_RETRIES;
}
