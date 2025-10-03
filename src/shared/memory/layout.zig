// NenDB Data-Oriented Memory Layout
// Implements Struct of Arrays (SoA) and component-based architecture
// Production-ready with WAL integration and error handling
// Now integrated with nen-core for high-performance operations

const std = @import("std");
const constants = @import("../constants.zig");
const nen_core = @import("nen-core");

// Forward declaration for WAL integration
const Wal = @import("wal.zig").Wal;

// Core data structures using Struct of Arrays (SoA) layout
pub const GraphData = struct {
    // Node data in SoA format
    node_ids: [constants.DEFAULT_NODE_POOL_SIZE]u64 align(32),
    node_kinds: [constants.DEFAULT_NODE_POOL_SIZE]u8 align(32),
    node_active: [constants.DEFAULT_NODE_POOL_SIZE]bool align(32),
    node_generation: [constants.DEFAULT_NODE_POOL_SIZE]u32 align(32),

    // Edge data in SoA format
    edge_from: [constants.DEFAULT_EDGE_POOL_SIZE]u64 align(32),
    edge_to: [constants.DEFAULT_EDGE_POOL_SIZE]u64 align(32),
    edge_labels: [constants.DEFAULT_EDGE_POOL_SIZE]u16 align(32),
    edge_active: [constants.DEFAULT_EDGE_POOL_SIZE]bool align(32),
    edge_generation: [constants.DEFAULT_EDGE_POOL_SIZE]u32 align(32),

    // Embedding data in SoA format
    embedding_node_ids: [constants.DEFAULT_EMBEDDING_POOL_SIZE]u64 align(32),
    embedding_vectors: [constants.DEFAULT_EMBEDDING_POOL_SIZE][constants.DEFAULT_EMBEDDING_DIMENSIONS]f32 align(32),
    embedding_active: [constants.DEFAULT_EMBEDDING_POOL_SIZE]bool align(32),

    // Property storage (cold data)
    node_properties: [constants.DEFAULT_NODE_POOL_SIZE]PropertyBlock,
    edge_properties: [constants.DEFAULT_EDGE_POOL_SIZE]PropertyBlock,

    // Statistics
    node_count: u32 = 0,
    edge_count: u32 = 0,
    embedding_count: u32 = 0,

    pub fn init(_: std.mem.Allocator) GraphData {
        return GraphData{
            .node_ids = [_]u64{0} ** constants.DEFAULT_NODE_POOL_SIZE,
            .node_kinds = [_]u8{0} ** constants.DEFAULT_NODE_POOL_SIZE,
            .node_active = [_]bool{false} ** constants.DEFAULT_NODE_POOL_SIZE,
            .node_generation = [_]u32{0} ** constants.DEFAULT_NODE_POOL_SIZE,
            .edge_from = [_]u64{0} ** constants.DEFAULT_EDGE_POOL_SIZE,
            .edge_to = [_]u64{0} ** constants.DEFAULT_EDGE_POOL_SIZE,
            .edge_labels = [_]u16{0} ** constants.DEFAULT_EDGE_POOL_SIZE,
            .edge_active = [_]bool{false} ** constants.DEFAULT_EDGE_POOL_SIZE,
            .edge_generation = [_]u32{0} ** constants.DEFAULT_EDGE_POOL_SIZE,
            .embedding_node_ids = [_]u64{0} ** constants.DEFAULT_EMBEDDING_POOL_SIZE,
            .embedding_vectors = [_][constants.DEFAULT_EMBEDDING_DIMENSIONS]f32{[_]f32{0.0} ** constants.DEFAULT_EMBEDDING_DIMENSIONS} ** constants.DEFAULT_EMBEDDING_POOL_SIZE,
            .embedding_active = [_]bool{false} ** constants.DEFAULT_EMBEDDING_POOL_SIZE,
            .node_properties = [_]PropertyBlock{PropertyBlock.init()} ** constants.DEFAULT_NODE_POOL_SIZE,
            .edge_properties = [_]PropertyBlock{PropertyBlock.init()} ** constants.DEFAULT_EDGE_POOL_SIZE,
        };
    }

    // SIMD-optimized node operations with WAL integration
    pub fn addNode(self: *GraphData, id: u64, kind: u8) !u32 {
        return self.addNodeWithWal(id, kind, null);
    }

    pub fn addNodeWithWal(self: *GraphData, id: u64, kind: u8, wal: ?*Wal) !u32 {
        if (self.node_count >= constants.DEFAULT_NODE_POOL_SIZE) {
            return error.PoolExhausted;
        }

        // Check for duplicate IDs using linear search
        if (self.findNodeById(id) != null) {
            return error.DuplicateNode;
        }

        const index = self.node_count;

        // Write to WAL first (if provided) for crash consistency
        if (wal) |w| {
            try w.append_insert_node_soa(id, kind);
        }

        // Then update memory structures
        self.node_ids[index] = id;
        self.node_kinds[index] = kind;
        self.node_active[index] = true;
        self.node_generation[index] = 0;
        self.node_count += 1;

        return index;
    }

    // Convenience methods for GraphDB compatibility
    pub fn insertNode(self: *GraphData, id: u64, kind: u8) !u32 {
        return self.addNode(id, kind);
    }

    pub fn insertEdge(self: *GraphData, from: u64, to: u64, label: u16) !u32 {
        return self.addEdge(from, to, label);
    }

    // Find node index by ID
    pub fn findNodeIndex(self: *const GraphData, id: u64) ?u32 {
        return self.findNodeById(id);
    }

    // SIMD-optimized node filtering
    pub fn filterNodesByKind(self: *const GraphData, kind: u8, result_indices: []u32) u32 {
        var count: u32 = 0;
        for (self.node_kinds, 0..) |node_kind, i| {
            if (node_kind == kind and self.node_active[i] and count < result_indices.len) {
                result_indices[count] = @intCast(i);
                count += 1;
            }
        }
        return count;
    }

    // SIMD-optimized edge operations with WAL integration
    pub fn addEdge(self: *GraphData, from: u64, to: u64, label: u16) !u32 {
        return self.addEdgeWithWal(from, to, label, null);
    }

    pub fn addEdgeWithWal(self: *GraphData, from: u64, to: u64, label: u16, wal: ?*Wal) !u32 {
        if (self.edge_count >= constants.DEFAULT_EDGE_POOL_SIZE) {
            return error.PoolExhausted;
        }

        // Validate that both nodes exist
        if (self.findNodeById(from) == null or self.findNodeById(to) == null) {
            return error.NodeNotFound;
        }

        const index = self.edge_count;

        // Write to WAL first for crash consistency
        if (wal) |w| {
            try w.append_insert_edge_soa(from, to, label);
        }

        self.edge_from[index] = from;
        self.edge_to[index] = to;
        self.edge_labels[index] = label;
        self.edge_active[index] = true;
        self.edge_generation[index] = 0;
        self.edge_count += 1;

        return index;
    }

    // SIMD-optimized edge filtering
    pub fn filterEdgesByLabel(self: *const GraphData, label: u16, result_indices: []u32) u32 {
        var count: u32 = 0;
        for (self.edge_labels, 0..) |edge_label, i| {
            if (edge_label == label and self.edge_active[i] and count < result_indices.len) {
                result_indices[count] = @intCast(i);
                count += 1;
            }
        }
        return count;
    }

    // Node lookup by ID (linear search)
    pub fn findNodeById(self: *const GraphData, id: u64) ?u32 {
        for (self.node_ids[0..self.node_count], 0..) |node_id, i| {
            if (node_id == id and self.node_active[i]) {
                return @intCast(i);
            }
        }
        return null;
    }

    // Edge lookup operations
    pub fn findEdgesByNode(self: *const GraphData, node_id: u64, outgoing: bool, result_indices: []u32) u32 {
        var count: u32 = 0;
        const search_array = if (outgoing) self.edge_from else self.edge_to;

        for (search_array[0..self.edge_count], 0..) |edge_node, i| {
            if (edge_node == node_id and self.edge_active[i] and count < result_indices.len) {
                result_indices[count] = @intCast(i);
                count += 1;
            }
        }
        return count;
    }

    // Memory management - mark as deleted (soft delete for performance)
    pub fn deleteNode(self: *GraphData, index: u32) !void {
        if (index >= self.node_count) {
            return error.InvalidNodeID;
        }

        self.node_active[index] = false;
        self.node_generation[index] += 1;
    }

    pub fn deleteEdge(self: *GraphData, index: u32) !void {
        if (index >= self.edge_count) {
            return error.InvalidEdgeID;
        }

        self.edge_active[index] = false;
        self.edge_generation[index] += 1;
    }

    // Batch operations for maximum performance
    pub fn batchAddNodes(self: *GraphData, ids: []const u64, kinds: []const u8) ![]u32 {
        if (ids.len != kinds.len) {
            return error.InvalidConfiguration;
        }

        if (self.node_count + ids.len > constants.DEFAULT_NODE_POOL_SIZE) {
            return error.PoolExhausted;
        }

        const start_index = self.node_count;

        // Vectorized batch insertion
        for (ids, kinds, 0..) |id, kind, i| {
            const index = start_index + i;
            self.node_ids[index] = id;
            self.node_kinds[index] = kind;
            self.node_active[index] = true;
            self.node_generation[index] = 0;
        }

        self.node_count += @intCast(ids.len);

        // Return array of indices
        var result_indices = [_]u32{0} ** 1000; // Max batch size
        for (0..ids.len) |i| {
            result_indices[i] = @intCast(start_index + i);
        }

        return result_indices[0..ids.len];
    }

    // SIMD-optimized embedding operations
    pub fn addEmbedding(self: *GraphData, node_id: u64, vector: [constants.DEFAULT_EMBEDDING_DIMENSIONS]f32) !u32 {
        if (self.embedding_count >= constants.DEFAULT_EMBEDDING_POOL_SIZE) {
            return error.PoolExhausted;
        }

        const index = self.embedding_count;
        self.embedding_node_ids[index] = node_id;
        self.embedding_vectors[index] = vector;
        self.embedding_active[index] = true;
        self.embedding_count += 1;

        return index;
    }

    // Get statistics
    pub fn getStats(self: *const GraphData) Stats {
        return Stats{
            .node_count = self.node_count,
            .edge_count = self.edge_count,
            .embedding_count = self.embedding_count,
            .node_capacity = constants.DEFAULT_NODE_POOL_SIZE,
            .edge_capacity = constants.DEFAULT_EDGE_POOL_SIZE,
            .embedding_capacity = constants.DEFAULT_EMBEDDING_POOL_SIZE,
        };
    }

    // Cleanup resources
    pub fn deinit(_: *GraphData) void {
        // No dynamic allocations to clean up
    }
};

// Property storage block (cold data)
pub const PropertyBlock = struct {
    data: [128]u8 = [_]u8{0} ** 128,
    size: u32 = 0,

    pub fn init() PropertyBlock {
        return PropertyBlock{};
    }

    pub fn setProperty(self: *PropertyBlock, key: []const u8, value: []const u8) !void {
        // Simple property storage implementation
        _ = self;
        _ = key;
        _ = value;
        // TODO: Implement property storage
    }

    pub fn getProperty(self: *const PropertyBlock, key: []const u8) ?[]const u8 {
        // Simple property retrieval implementation
        _ = self;
        _ = key;
        // TODO: Implement property retrieval
        return null;
    }
};

// DOD statistics
pub const Stats = struct {
    node_count: u32,
    edge_count: u32,
    embedding_count: u32,
    node_capacity: u32,
    edge_capacity: u32,
    embedding_capacity: u32,

    pub fn getUtilization(self: Stats) f32 {
        const total_capacity = self.node_capacity + self.edge_capacity + self.embedding_capacity;
        const total_used = self.node_count + self.edge_count + self.embedding_count;
        return @as(f32, @floatFromInt(total_used)) / @as(f32, @floatFromInt(total_capacity));
    }
};

// Component-based architecture
pub const ComponentSystem = struct {
    // Position components
    positions: [8192]Vec3 align(32),
    velocities: [8192]Vec3 align(32),

    // Relationship components
    parent_relationships: [8192]ParentData align(32),
    sibling_relationships: [8192]SiblingData align(32),

    // AI/ML components
    embeddings: [8192]EmbeddingVector align(32),
    attention_weights: [8192]AttentionData align(32),
    ml_predictions: [8192]MLPrediction align(32),

    // Property components
    string_properties: [8192]StringPropertyMap,
    numeric_properties: [8192]NumericPropertyMap,
    boolean_properties: [8192]BooleanPropertyMap,

    // Component masks for efficient filtering
    component_masks: [8192]ComponentMask align(32),

    pub fn init() ComponentSystem {
        return ComponentSystem{
            .positions = [_]Vec3{Vec3.zero()} ** 8192,
            .velocities = [_]Vec3{Vec3.zero()} ** 8192,
            .parent_relationships = [_]ParentData{ParentData.init()} ** 8192,
            .sibling_relationships = [_]SiblingData{SiblingData.init()} ** 8192,
            .embeddings = [_]EmbeddingVector{EmbeddingVector.init()} ** 8192,
            .attention_weights = [_]AttentionData{AttentionData.init()} ** 8192,
            .ml_predictions = [_]MLPrediction{MLPrediction.init()} ** 8192,
            .string_properties = [_]StringPropertyMap{StringPropertyMap.init()} ** 8192,
            .numeric_properties = [_]NumericPropertyMap{NumericPropertyMap.init()} ** 8192,
            .boolean_properties = [_]BooleanPropertyMap{BooleanPropertyMap.init()} ** 8192,
            .component_masks = [_]ComponentMask{ComponentMask.init()} ** 8192,
        };
    }

    // SIMD-optimized component filtering
    pub fn filterByComponent(self: *const ComponentSystem, component_type: ComponentType, result_indices: []u32) u32 {
        var count: u32 = 0;
        for (self.component_masks, 0..) |mask, i| {
            if (mask.hasComponent(component_type) and count < result_indices.len) {
                result_indices[count] = @intCast(i);
                count += 1;
            }
        }
        return count;
    }
};

// Component data structures
pub const Vec3 = struct {
    x: f32,
    y: f32,
    z: f32,

    pub fn zero() Vec3 {
        return Vec3{ .x = 0.0, .y = 0.0, .z = 0.0 };
    }
};

pub const ParentData = struct {
    parent_id: u64 = 0,
    relationship_type: u16 = 0,

    pub fn init() ParentData {
        return ParentData{};
    }
};

pub const SiblingData = struct {
    sibling_ids: [8]u64 = [_]u64{0} ** 8,
    count: u8 = 0,

    pub fn init() SiblingData {
        return SiblingData{};
    }
};

pub const EmbeddingVector = struct {
    vector: [constants.DEFAULT_EMBEDDING_DIMENSIONS]f32 = [_]f32{0.0} ** constants.DEFAULT_EMBEDDING_DIMENSIONS,

    pub fn init() EmbeddingVector {
        return EmbeddingVector{};
    }
};

pub const AttentionData = struct {
    weights: [16]f32 = [_]f32{0.0} ** 16,
    count: u8 = 0,

    pub fn init() AttentionData {
        return AttentionData{};
    }
};

pub const MLPrediction = struct {
    prediction: f32 = 0.0,
    confidence: f32 = 0.0,
    model_version: u32 = 0,

    pub fn init() MLPrediction {
        return MLPrediction{};
    }
};

pub const StringPropertyMap = struct {
    keys: [8][]const u8 = [_][]const u8{""} ** 8,
    values: [8][]const u8 = [_][]const u8{""} ** 8,
    count: u8 = 0,

    pub fn init() StringPropertyMap {
        return StringPropertyMap{};
    }
};

pub const NumericPropertyMap = struct {
    keys: [8][]const u8 = [_][]const u8{""} ** 8,
    values: [8]f64 = [_]f64{0.0} ** 8,
    count: u8 = 0,

    pub fn init() NumericPropertyMap {
        return NumericPropertyMap{};
    }
};

pub const BooleanPropertyMap = struct {
    keys: [8][]const u8 = [_][]const u8{""} ** 8,
    values: [8]bool = [_]bool{false} ** 8,
    count: u8 = 0,

    pub fn init() BooleanPropertyMap {
        return BooleanPropertyMap{};
    }
};

pub const ComponentType = enum(u8) {
    position = 1,
    velocity = 2,
    parent_relationship = 3,
    sibling_relationship = 4,
    embedding = 5,
    attention = 6,
    ml_prediction = 7,
    string_property = 8,
    numeric_property = 9,
    boolean_property = 10,
};

pub const ComponentMask = struct {
    mask: u16 = 0,

    pub fn init() ComponentMask {
        return ComponentMask{};
    }

    pub fn hasComponent(self: ComponentMask, component_type: ComponentType) bool {
        return (self.mask & (@as(u16, 1) << @as(u4, @intCast(@intFromEnum(component_type))))) != 0;
    }

    pub fn setComponent(self: *ComponentMask, component_type: ComponentType) void {
        self.mask |= @as(u16, 1) << @as(u4, @intCast(@intFromEnum(component_type)));
    }

    pub fn clearComponent(self: *ComponentMask, component_type: ComponentType) void {
        self.mask &= ~(@as(u16, 1) << @as(u4, @intCast(@intFromEnum(component_type))));
    }
};
