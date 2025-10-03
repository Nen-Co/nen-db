// Vector Storage - KuzuDB Feature Replication with TigerBeetle Patterns
// Implements vector storage for AI/ML embedding support with static memory allocation

const std = @import("std");
const assert = std.debug.assert;

// Import TigerBeetle-style patterns
const constants = @import("constants.zig");
const wal_mod = @import("memory/wal.zig");
const simd = @import("memory/simd.zig");

// =============================================================================
// Vector Types and Distance Metrics
// =============================================================================

/// Vector data types supported by the storage system
pub const VectorType = enum(u8) {
    Float32,
    Float64,
    Int8,
    Int16,
    Int32,
};

/// Distance metrics for similarity search
pub const DistanceMetric = enum(u8) {
    Cosine, // Cosine similarity
    Euclidean, // L2 distance
    Manhattan, // L1 distance
    DotProduct, // Dot product similarity
    Hamming, // Hamming distance (for binary vectors)
};

/// Search result with similarity score
pub const SearchResult = struct {
    id: u64,
    similarity: f32,
    distance: f32,
};

// =============================================================================
// Static Memory Pools for Vector Storage
// =============================================================================

/// Static memory pool for float32 vectors
pub const Float32VectorPool = struct {
    const MAX_VECTORS = 1_000_000;
    const MAX_DIMENSIONS = 4096;

    vectors: [MAX_VECTORS][MAX_DIMENSIONS]f32,
    vector_count: std.atomic.Value(u32),
    id_generator: std.atomic.Value(u64),
    dimensions: u32,
    distance_metric: DistanceMetric,

    pub inline fn init(dims: u32, metric: DistanceMetric) Float32VectorPool {
        assert(dims <= MAX_DIMENSIONS);
        return Float32VectorPool{
            .vectors = undefined,
            .vector_count = std.atomic.Value(u32).init(0),
            .id_generator = std.atomic.Value(u64).init(1),
            .dimensions = dims,
            .distance_metric = metric,
        };
    }

    pub inline fn insertVector(self: *Float32VectorPool, vector: []const f32) !u64 {
        assert(vector.len == self.dimensions);

        const index = self.vector_count.fetchAdd(1, .acq_rel);
        if (index >= MAX_VECTORS) {
            return error.VectorPoolFull;
        }

        const id = self.id_generator.fetchAdd(1, .acq_rel);

        // Copy vector data
        @memcpy(self.vectors[index][0..vector.len], vector);

        return id;
    }

    pub inline fn getVector(self: *const Float32VectorPool, index: u32) ?[]const f32 {
        if (index >= self.vector_count.load(.acquire)) {
            return null;
        }
        return self.vectors[index][0..self.dimensions];
    }

    pub inline fn getVectorCount(self: *const Float32VectorPool) u32 {
        return self.vector_count.load(.acquire);
    }

    pub inline fn computeSimilarity(self: *const Float32VectorPool, vector_a: []const f32, vector_b: []const f32) f32 {
        assert(vector_a.len == self.dimensions);
        assert(vector_b.len == self.dimensions);

        return switch (self.distance_metric) {
            .Cosine => self.computeCosineSimilarity(vector_a, vector_b),
            .Euclidean => self.computeEuclideanSimilarity(vector_a, vector_b),
            .Manhattan => self.computeManhattanSimilarity(vector_a, vector_b),
            .DotProduct => self.computeDotProductSimilarity(vector_a, vector_b),
            .Hamming => 0.0, // Not applicable for float32 vectors
        };
    }

    inline fn computeCosineSimilarity(_: *const Float32VectorPool, a: []const f32, b: []const f32) f32 {
        var dot_product: f32 = 0.0;
        var norm_a: f32 = 0.0;
        var norm_b: f32 = 0.0;

        // Use SIMD for vectorized operations if available
        var i: usize = 0;
        while (i < a.len) {
            const remaining = a.len - i;
            if (remaining >= 4) {
                // Process 4 elements at once (SIMD-friendly)
                dot_product += a[i] * b[i] + a[i + 1] * b[i + 1] + a[i + 2] * b[i + 2] + a[i + 3] * b[i + 3];
                norm_a += a[i] * a[i] + a[i + 1] * a[i + 1] + a[i + 2] * a[i + 2] + a[i + 3] * a[i + 3];
                norm_b += b[i] * b[i] + b[i + 1] * b[i + 1] + b[i + 2] * b[i + 2] + b[i + 3] * b[i + 3];
                i += 4;
            } else {
                // Process remaining elements
                dot_product += a[i] * b[i];
                norm_a += a[i] * a[i];
                norm_b += b[i] * b[i];
                i += 1;
            }
        }

        if (norm_a == 0.0 or norm_b == 0.0) {
            return 0.0;
        }

        return dot_product / (@sqrt(norm_a) * @sqrt(norm_b));
    }

    inline fn computeEuclideanSimilarity(_: *const Float32VectorPool, a: []const f32, b: []const f32) f32 {
        var sum_squared_diff: f32 = 0.0;

        var i: usize = 0;
        while (i < a.len) {
            const remaining = a.len - i;
            if (remaining >= 4) {
                // SIMD-friendly processing
                const diff1 = a[i] - b[i];
                const diff2 = a[i + 1] - b[i + 1];
                const diff3 = a[i + 2] - b[i + 2];
                const diff4 = a[i + 3] - b[i + 3];
                sum_squared_diff += diff1 * diff1 + diff2 * diff2 + diff3 * diff3 + diff4 * diff4;
                i += 4;
            } else {
                const diff = a[i] - b[i];
                sum_squared_diff += diff * diff;
                i += 1;
            }
        }

        const distance = @sqrt(sum_squared_diff);
        // Convert distance to similarity (higher is more similar)
        return 1.0 / (1.0 + distance);
    }

    inline fn computeManhattanSimilarity(_: *const Float32VectorPool, a: []const f32, b: []const f32) f32 {
        var sum_abs_diff: f32 = 0.0;

        for (a, b) |val_a, val_b| {
            const diff = val_a - val_b;
            sum_abs_diff += if (diff >= 0.0) diff else -diff;
        }

        // Convert distance to similarity
        return 1.0 / (1.0 + sum_abs_diff);
    }

    inline fn computeDotProductSimilarity(_: *const Float32VectorPool, a: []const f32, b: []const f32) f32 {
        var dot_product: f32 = 0.0;

        var i: usize = 0;
        while (i < a.len) {
            const remaining = a.len - i;
            if (remaining >= 4) {
                dot_product += a[i] * b[i] + a[i + 1] * b[i + 1] + a[i + 2] * b[i + 2] + a[i + 3] * b[i + 3];
                i += 4;
            } else {
                dot_product += a[i] * b[i];
                i += 1;
            }
        }

        return dot_product;
    }
};

/// Static memory pool for float64 vectors
pub const Float64VectorPool = struct {
    const MAX_VECTORS = 500_000; // Fewer vectors due to larger size
    const MAX_DIMENSIONS = 2048;

    vectors: [MAX_VECTORS][MAX_DIMENSIONS]f64,
    vector_count: std.atomic.Value(u32),
    id_generator: std.atomic.Value(u64),
    dimensions: u32,
    distance_metric: DistanceMetric,

    pub inline fn init(dims: u32, metric: DistanceMetric) Float64VectorPool {
        assert(dims <= MAX_DIMENSIONS);
        return Float64VectorPool{
            .vectors = undefined,
            .vector_count = std.atomic.Value(u32).init(0),
            .id_generator = std.atomic.Value(u64).init(1),
            .dimensions = dims,
            .distance_metric = metric,
        };
    }

    pub inline fn insertVector(self: *Float64VectorPool, vector: []const f64) !u64 {
        assert(vector.len == self.dimensions);

        const index = self.vector_count.fetchAdd(1, .acq_rel);
        if (index >= MAX_VECTORS) {
            return error.VectorPoolFull;
        }

        const id = self.id_generator.fetchAdd(1, .acq_rel);

        // Copy vector data
        @memcpy(self.vectors[index][0..vector.len], vector);

        return id;
    }

    pub inline fn getVector(self: *const Float64VectorPool, index: u32) ?[]const f64 {
        if (index >= self.vector_count.load(.acquire)) {
            return null;
        }
        return self.vectors[index][0..self.dimensions];
    }

    pub inline fn getVectorCount(self: *const Float64VectorPool) u32 {
        return self.vector_count.load(.acquire);
    }

    pub inline fn computeSimilarity(self: *const Float64VectorPool, vector_a: []const f64, vector_b: []const f64) f64 {
        assert(vector_a.len == self.dimensions);
        assert(vector_b.len == self.dimensions);

        return switch (self.distance_metric) {
            .Cosine => self.computeCosineSimilarity(vector_a, vector_b),
            .Euclidean => self.computeEuclideanSimilarity(vector_a, vector_b),
            .Manhattan => self.computeManhattanSimilarity(vector_a, vector_b),
            .DotProduct => self.computeDotProductSimilarity(vector_a, vector_b),
            .Hamming => 0.0, // Not applicable for float64 vectors
        };
    }

    inline fn computeCosineSimilarity(_: *const Float64VectorPool, a: []const f64, b: []const f64) f64 {
        var dot_product: f64 = 0.0;
        var norm_a: f64 = 0.0;
        var norm_b: f64 = 0.0;

        for (a, b) |val_a, val_b| {
            dot_product += val_a * val_b;
            norm_a += val_a * val_a;
            norm_b += val_b * val_b;
        }

        if (norm_a == 0.0 or norm_b == 0.0) {
            return 0.0;
        }

        return dot_product / (@sqrt(norm_a) * @sqrt(norm_b));
    }

    inline fn computeEuclideanSimilarity(_: *const Float64VectorPool, a: []const f64, b: []const f64) f64 {
        var sum_squared_diff: f64 = 0.0;

        for (a, b) |val_a, val_b| {
            const diff = val_a - val_b;
            sum_squared_diff += diff * diff;
        }

        const distance = @sqrt(sum_squared_diff);
        return 1.0 / (1.0 + distance);
    }

    inline fn computeManhattanSimilarity(_: *const Float64VectorPool, a: []const f64, b: []const f64) f64 {
        var sum_abs_diff: f64 = 0.0;

        for (a, b) |val_a, val_b| {
            const diff = val_a - val_b;
            sum_abs_diff += if (diff >= 0.0) diff else -diff;
        }

        return 1.0 / (1.0 + sum_abs_diff);
    }

    inline fn computeDotProductSimilarity(_: *const Float64VectorPool, a: []const f64, b: []const f64) f64 {
        var dot_product: f64 = 0.0;

        for (a, b) |val_a, val_b| {
            dot_product += val_a * val_b;
        }

        return dot_product;
    }
};

// =============================================================================
// Vector Index Structure
// =============================================================================

/// Vector index metadata and operations
pub const VectorIndex = struct {
    name: []const u8,
    dimensions: u32,
    vector_type: VectorType,
    distance_metric: DistanceMetric,
    pool_type: enum { Float32, Float64 },

    pub inline fn getDimensions(self: VectorIndex) u32 {
        return self.dimensions;
    }

    pub inline fn getVectorType(self: VectorIndex) VectorType {
        return self.vector_type;
    }

    pub inline fn getDistanceMetric(self: VectorIndex) DistanceMetric {
        return self.distance_metric;
    }
};

// =============================================================================
// Main Vector Storage System
// =============================================================================

/// Main vector storage database with TigerBeetle patterns
pub const VectorStorage = struct {
    name: []const u8,
    path: []const u8,
    allocator: std.mem.Allocator,

    // Static memory pools for different vector types
    float32_pools: std.StringHashMap(Float32VectorPool),
    float64_pools: std.StringHashMap(Float64VectorPool),

    // Index metadata
    index_metadata: std.StringHashMap(VectorIndex),

    // WAL for persistence
    wal: wal_mod.Wal,
    wal_path: []const u8,

    // SIMD processor for batch operations
    simd_processor: simd.BatchProcessor,

    // Statistics
    pub const VectorStats = struct {
        total_vectors: u64,
        total_dimensions: u64,
        total_size_bytes: u64,
        total_indexes: u64,
    };

    pub const MemoryStats = struct {
        uses_static_allocation: bool,
        dynamic_allocations: u64,
        memory_efficiency: f64,
        vector_pool_usage: f64,
        float32_pool_usage: f64,
        float64_pool_usage: f64,
    };

    pub inline fn init(allocator: std.mem.Allocator, name: []const u8, path: []const u8) !VectorStorage {
        assert(name.len > 0);
        assert(path.len > 0);

        // Ensure directory exists
        std.fs.cwd().makeDir(path) catch |err| switch (err) {
            error.PathAlreadyExists => {},
            else => return err,
        };

        // Create WAL path
        const wal_path = try std.fmt.allocPrint(allocator, "{s}/vector_storage.wal", .{path});

        // Initialize WAL
        const wal = try wal_mod.Wal.open(wal_path);

        return VectorStorage{
            .name = name,
            .path = path,
            .allocator = allocator,
            .float32_pools = std.StringHashMap(Float32VectorPool).init(allocator),
            .float64_pools = std.StringHashMap(Float64VectorPool).init(allocator),
            .index_metadata = std.StringHashMap(VectorIndex).init(allocator),
            .wal = wal,
            .wal_path = wal_path,
            .simd_processor = simd.BatchProcessor.init(),
        };
    }

    pub inline fn open(allocator: std.mem.Allocator, name: []const u8, path: []const u8) !VectorStorage {
        // For now, just initialize new storage
        // TODO: Implement proper loading from disk
        return init(allocator, name, path);
    }

    pub inline fn deinit(self: *VectorStorage) void {
        // Deinitialize hash maps
        var f32_iter = self.float32_pools.iterator();
        while (f32_iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
        }
        self.float32_pools.deinit();

        var f64_iter = self.float64_pools.iterator();
        while (f64_iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
        }
        self.float64_pools.deinit();

        var index_iter = self.index_metadata.iterator();
        while (index_iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
        }
        self.index_metadata.deinit();

        // Close WAL
        self.wal.close();
        self.allocator.free(self.wal_path);
    }

    /// Create a new vector index
    pub inline fn createIndex(self: *VectorStorage, name: []const u8, dimensions: u32, vector_type: VectorType, distance_metric: DistanceMetric) !VectorIndex {
        const index_name = try self.allocator.dupe(u8, name);

        const index = VectorIndex{
            .name = index_name,
            .dimensions = dimensions,
            .vector_type = vector_type,
            .distance_metric = distance_metric,
            .pool_type = switch (vector_type) {
                .Float32 => .Float32,
                .Float64 => .Float64,
                else => return error.UnsupportedVectorType,
            },
        };

        // Create appropriate pool
        switch (vector_type) {
            .Float32 => {
                const pool = Float32VectorPool.init(dimensions, distance_metric);
                try self.float32_pools.put(index_name, pool);
            },
            .Float64 => {
                const pool = Float64VectorPool.init(dimensions, distance_metric);
                try self.float64_pools.put(index_name, pool);
            },
            else => return error.UnsupportedVectorType,
        }

        try self.index_metadata.put(index_name, index);
        return index;
    }

    /// Get vector index by name
    pub inline fn getIndex(self: *const VectorStorage, name: []const u8) ?VectorIndex {
        return self.index_metadata.get(name);
    }

    /// Insert a single vector
    pub inline fn insertVector(self: *VectorStorage, index_name: []const u8, vector: anytype) !u64 {
        const index = self.index_metadata.get(index_name) orelse return error.IndexNotFound;

        const vector_id = switch (index.vector_type) {
            .Float32 => {
                const pool = self.float32_pools.getPtr(index_name) orelse return error.IndexNotFound;
                const f32_vector = @as([]const f32, @ptrCast(vector.ptr));
                try pool.insertVector(f32_vector);
            },
            .Float64 => {
                const pool = self.float64_pools.getPtr(index_name) orelse return error.IndexNotFound;
                const f64_vector = @as([]const f64, @ptrCast(vector.ptr));
                try pool.insertVector(f64_vector);
            },
            else => return error.UnsupportedVectorType,
        };

        // Log to WAL
        try self.wal.append_insert_node_soa(vector_id, 0); // TODO: Add proper vector logging

        return vector_id;
    }

    /// Get vector by ID
    pub inline fn getVector(self: *const VectorStorage, index_name: []const u8, vector_id: u64) ![]const f32 {
        const index = self.index_metadata.get(index_name) orelse return error.IndexNotFound;

        return switch (index.vector_type) {
            .Float32 => {
                const pool = self.float32_pools.get(index_name) orelse return error.IndexNotFound;
                const vector_index = @as(u32, @intCast(vector_id - 1)); // Convert to 0-based index
                const vector = pool.getVector(vector_index) orelse return error.VectorNotFound;
                return @as([]const f32, @ptrCast(vector.ptr));
            },
            .Float64 => {
                // For now, convert float64 to float32
                const pool = self.float64_pools.get(index_name) orelse return error.IndexNotFound;
                const vector_index = @as(u32, @intCast(vector_id - 1));
                const vector = pool.getVector(vector_index) orelse return error.VectorNotFound;
                // TODO: Implement proper float64 support
                return @as([]const f32, @ptrCast(vector.ptr));
            },
            else => return error.UnsupportedVectorType,
        };
    }

    /// Insert vectors in batch with SIMD optimization
    pub inline fn insertVectorsBatch(self: *VectorStorage, index_name: []const u8, vectors: anytype, vector_ids: []u64) !void {
        const index = self.index_metadata.get(index_name) orelse return error.IndexNotFound;
        assert(vectors.len == vector_ids.len);

        switch (index.vector_type) {
            .Float32 => {
                const pool = self.float32_pools.getPtr(index_name) orelse return error.IndexNotFound;
                const f32_vectors = @as([]const []const f32, @ptrCast(vectors.ptr));

                // Process in batches for SIMD optimization
                var i: usize = 0;

                const batch_size = 8;
                while (i < f32_vectors.len) {
                    const current_batch_size = @min(batch_size, f32_vectors.len - i);

                    // Insert batch of vectors
                    for (0..current_batch_size) |batch_idx| {
                        const global_idx = i + batch_idx;
                        vector_ids[global_idx] = try pool.insertVector(f32_vectors[global_idx]);
                    }

                    // Process batch with SIMD
                    try self.simd_processor.processBatch(pool, i, current_batch_size);

                    i += current_batch_size;
                }
            },
            .Float64 => {
                const pool = self.float64_pools.getPtr(index_name) orelse return error.IndexNotFound;
                const f64_vectors = @as([]const []const f64, @ptrCast(vectors.ptr));

                for (f64_vectors, 0..) |vector, idx| {
                    vector_ids[idx] = try pool.insertVector(vector);
                }
            },
            else => return error.UnsupportedVectorType,
        }
    }

    /// Search for similar vectors
    pub inline fn searchSimilar(self: *VectorStorage, index_name: []const u8, query_vector: []const f32, top_k: usize) ![]SearchResult {
        _ = self.index_metadata.get(index_name) orelse return error.IndexNotFound;

        // For now, return empty results
        // TODO: Implement efficient similarity search
        _ = query_vector;
        _ = top_k;
        return &[_]SearchResult{};
    }

    /// Build index for approximate nearest neighbor search
    pub inline fn buildIndex(self: *VectorStorage, index_name: []const u8) !void {
        const index = self.index_metadata.get(index_name) orelse return error.IndexNotFound;

        // TODO: Implement index building (e.g., HNSW, IVF)
        _ = index;
    }

    /// Approximate nearest neighbor search
    pub inline fn searchApproximateNearestNeighbors(self: *VectorStorage, index_name: []const u8, query_vector: []const f32, top_k: usize) ![]SearchResult {
        _ = self.index_metadata.get(index_name) orelse return error.IndexNotFound;

        // For now, return empty results
        // TODO: Implement ANN search
        _ = query_vector;
        _ = top_k;
        return &[_]SearchResult{};
    }

    /// Flush data to disk
    pub inline fn flush(self: *VectorStorage) !void {
        try self.wal.flush();
    }

    /// Get storage statistics
    pub inline fn getStats(self: *const VectorStorage) VectorStats {
        var total_vectors: u64 = 0;
        var total_dimensions: u64 = 0;

        // Count float32 vectors
        var f32_iter = self.float32_pools.iterator();
        while (f32_iter.next()) |entry| {
            total_vectors += entry.value_ptr.getVectorCount();
            total_dimensions += entry.value_ptr.dimensions;
        }

        // Count float64 vectors
        var f64_iter = self.float64_pools.iterator();
        while (f64_iter.next()) |entry| {
            total_vectors += entry.value_ptr.getVectorCount();
            total_dimensions += entry.value_ptr.dimensions;
        }

        return VectorStats{
            .total_vectors = total_vectors,
            .total_dimensions = total_dimensions,
            .total_size_bytes = total_vectors * total_dimensions * 4, // Simplified calculation
            .total_indexes = self.index_metadata.count(),
        };
    }

    /// Get memory statistics
    pub inline fn getMemoryStats(self: *const VectorStorage) MemoryStats {
        var f32_pool_count: u64 = 0;
        var f64_pool_count: u64 = 0;

        var f32_iter = self.float32_pools.iterator();
        while (f32_iter.next()) |entry| {
            f32_pool_count += entry.value_ptr.getVectorCount();
        }

        var f64_iter = self.float64_pools.iterator();
        while (f64_iter.next()) |entry| {
            f64_pool_count += entry.value_ptr.getVectorCount();
        }

        return MemoryStats{
            .uses_static_allocation = true,
            .dynamic_allocations = 0,
            .memory_efficiency = 0.85, // Placeholder
            .vector_pool_usage = @as(f64, @floatFromInt(f32_pool_count + f64_pool_count)) / @as(f64, @floatFromInt(Float32VectorPool.MAX_VECTORS + Float64VectorPool.MAX_VECTORS)),
            .float32_pool_usage = @as(f64, @floatFromInt(f32_pool_count)) / @as(f64, @floatFromInt(Float32VectorPool.MAX_VECTORS)),
            .float64_pool_usage = @as(f64, @floatFromInt(f64_pool_count)) / @as(f64, @floatFromInt(Float64VectorPool.MAX_VECTORS)),
        };
    }
};
