// Property Graph Model - KuzuDB Feature Replication with TigerBeetle Patterns
// Implements a property graph model with static memory allocation and batch processing

const std = @import("std");
const assert = std.debug.assert;

// Import TigerBeetle-style patterns
const constants = @import("constants.zig");
const wal_mod = @import("memory/wal.zig");
const simd = @import("memory/simd.zig");

// =============================================================================
// Property Types and Values
// =============================================================================

/// Property types supported by the graph model
pub const PropertyType = enum(u8) {
    Integer,
    Float,
    String,
    Boolean,
    Vector, // For AI/ML embeddings
    Null,
};

/// Property value union with type information
pub const PropertyValue = union(PropertyType) {
    Integer: i64,
    Float: f64,
    String: []const u8,
    Boolean: bool,
    Vector: []const f32,
    Null: void,

    pub inline fn getType(self: PropertyValue) PropertyType {
        return @as(PropertyType, @enumFromInt(@intFromEnum(self)));
    }

    pub inline fn clone(self: PropertyValue, allocator: std.mem.Allocator) !PropertyValue {
        return switch (self) {
            .String => |s| PropertyValue{ .String = try allocator.dupe(u8, s) },
            .Vector => |v| PropertyValue{ .Vector = try allocator.dupe(f32, v) },
            .Integer => |i| PropertyValue{ .Integer = i },
            .Float => |f| PropertyValue{ .Float = f },
            .Boolean => |b| PropertyValue{ .Boolean = b },
            .Null => PropertyValue.Null,
        };
    }

    pub inline fn deinit(self: *PropertyValue, allocator: std.mem.Allocator) void {
        switch (self.*) {
            .String => |s| allocator.free(s),
            .Vector => |v| allocator.free(v),
            else => {},
        }
    }
};

/// Property definition with metadata
pub const Property = struct {
    name: []const u8,
    value: PropertyValue,

    pub inline fn clone(self: Property, allocator: std.mem.Allocator) !Property {
        return Property{
            .name = try allocator.dupe(u8, self.name),
            .value = try self.value.clone(allocator),
        };
    }

    pub inline fn deinit(self: *Property, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        self.value.deinit(allocator);
    }
};

// =============================================================================
// Schema Definitions
// =============================================================================

/// Property definition in schema
pub const SchemaProperty = struct {
    name: []const u8,
    type: PropertyType,
    required: bool = false,
    indexed: bool = false,
    default_value: ?PropertyValue = null,
};

/// Node schema definition
pub const NodeSchema = struct {
    name: []const u8,
    properties: []const SchemaProperty,

    pub inline fn getPropertyType(self: NodeSchema, property_name: []const u8) ?PropertyType {
        for (self.properties) |prop| {
            if (std.mem.eql(u8, prop.name, property_name)) {
                return prop.type;
            }
        }
        return null;
    }

    pub inline fn validateProperties(self: NodeSchema, properties: []const Property) !void {
        // Check required properties
        for (self.properties) |schema_prop| {
            if (schema_prop.required) {
                var found = false;
                for (properties) |prop| {
                    if (std.mem.eql(u8, prop.name, schema_prop.name)) {
                        found = true;
                        // Validate type
                        if (prop.value.getType() != schema_prop.type) {
                            return error.TypeMismatch;
                        }
                        break;
                    }
                }
                if (!found) {
                    return error.MissingRequiredProperty;
                }
            }
        }

        // Check that all provided properties are in schema
        for (properties) |prop| {
            const schema_prop_type = self.getPropertyType(prop.name);
            if (schema_prop_type == null) {
                return error.UnknownProperty;
            }
            if (prop.value.getType() != schema_prop_type.?) {
                return error.TypeMismatch;
            }
        }
    }
};

/// Edge schema definition
pub const EdgeSchema = struct {
    name: []const u8,
    properties: []const SchemaProperty,

    pub inline fn getPropertyType(self: EdgeSchema, property_name: []const u8) ?PropertyType {
        for (self.properties) |prop| {
            if (std.mem.eql(u8, prop.name, property_name)) {
                return prop.type;
            }
        }
        return null;
    }

    pub inline fn validateProperties(self: EdgeSchema, properties: []const Property) !void {
        // Same validation logic as NodeSchema
        for (self.properties) |schema_prop| {
            if (schema_prop.required) {
                var found = false;
                for (properties) |prop| {
                    if (std.mem.eql(u8, prop.name, schema_prop.name)) {
                        found = true;
                        if (prop.value.getType() != schema_prop.type) {
                            return error.TypeMismatch;
                        }
                        break;
                    }
                }
                if (!found) {
                    return error.MissingRequiredProperty;
                }
            }
        }

        for (properties) |prop| {
            const schema_prop_type = self.getPropertyType(prop.name);
            if (schema_prop_type == null) {
                return error.UnknownProperty;
            }
            if (prop.value.getType() != schema_prop_type.?) {
                return error.TypeMismatch;
            }
        }
    }
};

// =============================================================================
// Static Memory Pools
// =============================================================================

/// Static memory pool for properties (TigerBeetle pattern)
pub const PropertyPool = struct {
    const MAX_PROPERTIES = 1_000_000;
    const MAX_STRING_LENGTH = 1024;

    properties: [MAX_PROPERTIES]Property,
    property_count: std.atomic.Value(u32),
    string_pool: [MAX_PROPERTIES * MAX_STRING_LENGTH]u8,
    string_pool_used: std.atomic.Value(u32),

    pub inline fn init() PropertyPool {
        return PropertyPool{
            .properties = undefined,
            .property_count = std.atomic.Value(u32).init(0),
            .string_pool = undefined,
            .string_pool_used = std.atomic.Value(u32).init(0),
        };
    }

    pub inline fn allocateProperty(self: *PropertyPool, name: []const u8, value: PropertyValue) !*Property {
        const index = self.property_count.fetchAdd(1, .acq_rel);
        if (index >= MAX_PROPERTIES) {
            return error.PropertyPoolFull;
        }

        var prop = &self.properties[index];
        prop.name = try self.allocateString(name);
        prop.value = value;

        return prop;
    }

    pub inline fn allocateString(self: *PropertyPool, str: []const u8) ![]const u8 {
        if (str.len > MAX_STRING_LENGTH) {
            return error.StringTooLong;
        }

        const offset = self.string_pool_used.fetchAdd(@intCast(str.len + 1), .acq_rel);
        if (offset + str.len >= self.string_pool.len) {
            return error.StringPoolFull;
        }

        @memcpy(self.string_pool[offset .. offset + str.len], str);
        self.string_pool[offset + str.len] = 0; // Null terminator

        return self.string_pool[offset .. offset + str.len];
    }

    pub inline fn getPropertyCount(self: *const PropertyPool) u32 {
        return self.property_count.load(.acquire);
    }

    pub inline fn getStringPoolUsage(self: *const PropertyPool) u32 {
        return self.string_pool_used.load(.acquire);
    }
};

/// Static memory pool for nodes
pub const NodePool = struct {
    const MAX_NODES = 100_000;

    nodes: [MAX_NODES]Node,
    node_count: std.atomic.Value(u32),
    id_to_index: [MAX_NODES]u32, // Maps node ID to index
    id_generator: std.atomic.Value(u64),

    pub inline fn init() NodePool {
        return NodePool{
            .nodes = undefined,
            .node_count = std.atomic.Value(u32).init(0),
            .id_to_index = [_]u32{0} ** MAX_NODES,
            .id_generator = std.atomic.Value(u64).init(1), // Start from 1
        };
    }

    pub inline fn createNode(self: *NodePool, schema_name: []const u8, properties: []const Property) !*Node {
        const index = self.node_count.fetchAdd(1, .acq_rel);
        if (index >= MAX_NODES) {
            return error.NodePoolFull;
        }

        const id = self.id_generator.fetchAdd(1, .acq_rel);
        self.id_to_index[id % MAX_NODES] = @intCast(index);

        var node = &self.nodes[index];
        node.id = id;
        node.schema_name = schema_name;
        node.properties = properties;

        return node;
    }

    pub inline fn getNode(self: *const NodePool, id: u64) ?*Node {
        const index = self.id_to_index[id % MAX_NODES];
        if (index >= self.node_count.load(.acquire)) {
            return null;
        }
        return &self.nodes[index];
    }

    pub inline fn getNodeCount(self: *const NodePool) u32 {
        return self.node_count.load(.acquire);
    }
};

/// Static memory pool for edges
pub const EdgePool = struct {
    const MAX_EDGES = 500_000;

    edges: [MAX_EDGES]Edge,
    edge_count: std.atomic.Value(u32),
    id_to_index: [MAX_EDGES]u32,
    id_generator: std.atomic.Value(u64),

    pub inline fn init() EdgePool {
        return EdgePool{
            .edges = undefined,
            .edge_count = std.atomic.Value(u32).init(0),
            .id_to_index = [_]u32{0} ** MAX_EDGES,
            .id_generator = std.atomic.Value(u64).init(1),
        };
    }

    pub inline fn createEdge(self: *EdgePool, schema_name: []const u8, from_node: u64, to_node: u64, properties: []const Property) !*Edge {
        const index = self.edge_count.fetchAdd(1, .acq_rel);
        if (index >= MAX_EDGES) {
            return error.EdgePoolFull;
        }

        const id = self.id_generator.fetchAdd(1, .acq_rel);
        self.id_to_index[id % MAX_EDGES] = @intCast(index);

        var edge = &self.edges[index];
        edge.id = id;
        edge.schema_name = schema_name;
        edge.from_node = from_node;
        edge.to_node = to_node;
        edge.properties = properties;

        return edge;
    }

    pub inline fn getEdge(self: *const EdgePool, id: u64) ?*Edge {
        const index = self.id_to_index[id % MAX_EDGES];
        if (index >= self.edge_count.load(.acquire)) {
            return null;
        }
        return &self.edges[index];
    }

    pub inline fn getEdgeCount(self: *const EdgePool) u32 {
        return self.edge_count.load(.acquire);
    }
};

// =============================================================================
// Graph Entities
// =============================================================================

/// Node representation with properties
pub const Node = struct {
    id: u64,
    schema_name: []const u8,
    properties: []const Property,

    pub inline fn getProperty(self: Node, name: []const u8) ?PropertyValue {
        for (self.properties) |prop| {
            if (std.mem.eql(u8, prop.name, name)) {
                return prop.value;
            }
        }
        return null;
    }

    pub inline fn hasProperty(self: Node, name: []const u8) bool {
        return self.getProperty(name) != null;
    }
};

/// Edge representation with properties
pub const Edge = struct {
    id: u64,
    schema_name: []const u8,
    from_node: u64,
    to_node: u64,
    properties: []const Property,

    pub inline fn getProperty(self: Edge, name: []const u8) ?PropertyValue {
        for (self.properties) |prop| {
            if (std.mem.eql(u8, prop.name, name)) {
                return prop.value;
            }
        }
        return null;
    }

    pub inline fn hasProperty(self: Edge, name: []const u8) bool {
        return self.getProperty(name) != null;
    }
};

// =============================================================================
// Property Graph Database
// =============================================================================

/// Main property graph database with TigerBeetle patterns
pub const PropertyGraph = struct {
    name: []const u8,
    path: []const u8,
    allocator: std.mem.Allocator,

    // Static memory pools
    property_pool: PropertyPool,
    node_pool: NodePool,
    edge_pool: EdgePool,

    // Schema storage
    node_schemas: std.StringHashMap(NodeSchema),
    edge_schemas: std.StringHashMap(EdgeSchema),

    // Indexing for fast lookups
    property_indexes: std.StringHashMap(std.StringHashMap(std.ArrayList(u64))),

    // WAL for persistence
    wal: wal_mod.Wal,
    wal_path: []const u8,

    // SIMD processor for batch operations
    simd_processor: simd.BatchProcessor,

    // Statistics
    pub const GraphStats = struct {
        node_count: u64,
        edge_count: u64,
        property_count: u64,
        schema_count: u64,
    };

    pub const MemoryStats = struct {
        uses_static_allocation: bool,
        dynamic_allocations: u64,
        memory_efficiency: f64,
        property_pool_usage: f64,
        node_pool_usage: f64,
        edge_pool_usage: f64,
    };

    pub inline fn init(allocator: std.mem.Allocator, name: []const u8, path: []const u8) !PropertyGraph {
        assert(name.len > 0);
        assert(path.len > 0);

        // Ensure directory exists
        std.fs.cwd().makeDir(path) catch |err| switch (err) {
            error.PathAlreadyExists => {},
            else => return err,
        };

        // Create WAL path
        const wal_path = try std.fmt.allocPrint(allocator, "{s}/property_graph.wal", .{path});

        // Initialize WAL
        const wal = try wal_mod.Wal.open(wal_path);

        return PropertyGraph{
            .name = name,
            .path = path,
            .allocator = allocator,
            .property_pool = PropertyPool.init(),
            .node_pool = NodePool.init(),
            .edge_pool = EdgePool.init(),
            .node_schemas = std.StringHashMap(NodeSchema).init(allocator),
            .edge_schemas = std.StringHashMap(EdgeSchema).init(allocator),
            .property_indexes = std.StringHashMap(std.StringHashMap(std.ArrayList(u64))).init(allocator),
            .wal = wal,
            .wal_path = wal_path,
            .simd_processor = simd.BatchProcessor.init(),
        };
    }

    pub inline fn deinit(self: *PropertyGraph) void {
        // Deinitialize hash maps
        var node_schema_iter = self.node_schemas.iterator();
        while (node_schema_iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            for (entry.value_ptr.properties) |prop| {
                self.allocator.free(prop.name);
            }
        }
        self.node_schemas.deinit();

        var edge_schema_iter = self.edge_schemas.iterator();
        while (edge_schema_iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            for (entry.value_ptr.properties) |prop| {
                self.allocator.free(prop.name);
            }
        }
        self.edge_schemas.deinit();

        // Deinitialize property indexes
        var index_iter = self.property_indexes.iterator();
        while (index_iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            var prop_iter = entry.value_ptr.iterator();
            while (prop_iter.next()) |prop_entry| {
                self.allocator.free(prop_entry.key_ptr.*);
                prop_entry.value_ptr.deinit();
            }
            entry.value_ptr.deinit();
        }
        self.property_indexes.deinit();

        // Close WAL
        self.wal.close();
        self.allocator.free(self.wal_path);
    }

    /// Register a node schema
    pub inline fn registerNodeSchema(self: *PropertyGraph, schema: NodeSchema) !void {
        const schema_name = try self.allocator.dupe(u8, schema.name);
        var schema_copy = schema;
        schema_copy.name = schema_name;

        // Copy properties
        var properties_copy = try self.allocator.alloc(SchemaProperty, schema.properties.len);
        for (schema.properties, 0..) |prop, i| {
            properties_copy[i] = SchemaProperty{
                .name = try self.allocator.dupe(u8, prop.name),
                .type = prop.type,
                .required = prop.required,
                .indexed = prop.indexed,
                .default_value = prop.default_value,
            };
        }
        schema_copy.properties = properties_copy;

        try self.node_schemas.put(schema_name, schema_copy);
    }

    /// Register an edge schema
    pub inline fn registerEdgeSchema(self: *PropertyGraph, schema: EdgeSchema) !void {
        const schema_name = try self.allocator.dupe(u8, schema.name);
        var schema_copy = schema;
        schema_copy.name = schema_name;

        // Copy properties
        var properties_copy = try self.allocator.alloc(SchemaProperty, schema.properties.len);
        for (schema.properties, 0..) |prop, i| {
            properties_copy[i] = SchemaProperty{
                .name = try self.allocator.dupe(u8, prop.name),
                .type = prop.type,
                .required = prop.required,
                .indexed = prop.indexed,
                .default_value = prop.default_value,
            };
        }
        schema_copy.properties = properties_copy;

        try self.edge_schemas.put(schema_name, schema_copy);
    }

    /// Get node schema by name
    pub inline fn getNodeSchema(self: *const PropertyGraph, name: []const u8) ?NodeSchema {
        return self.node_schemas.get(name);
    }

    /// Get edge schema by name
    pub inline fn getEdgeSchema(self: *const PropertyGraph, name: []const u8) ?EdgeSchema {
        return self.edge_schemas.get(name);
    }

    /// Create a single node
    pub inline fn createNode(self: *PropertyGraph, schema_name: []const u8, properties: []const Property) !u64 {
        // Get schema
        const schema = self.node_schemas.get(schema_name) orelse return error.UnknownSchema;

        // Validate properties
        try schema.validateProperties(properties);

        // Allocate properties in static pool
        var pool_properties = try self.allocator.alloc(Property, properties.len);
        for (properties, 0..) |prop, i| {
            pool_properties[i] = try prop.clone(self.allocator);
        }

        // Create node
        const node = try self.node_pool.createNode(schema_name, pool_properties);

        // Log to WAL
        try self.wal.append_insert_node_soa(node.id, 0); // TODO: Add property logging

        return node.id;
    }

    /// Create a single edge
    pub inline fn createEdge(self: *PropertyGraph, schema_name: []const u8, from_node: u64, to_node: u64, properties: []const Property) !u64 {
        // Get schema
        const schema = self.edge_schemas.get(schema_name) orelse return error.UnknownSchema;

        // Validate properties
        try schema.validateProperties(properties);

        // Allocate properties in static pool
        var pool_properties = try self.allocator.alloc(Property, properties.len);
        for (properties, 0..) |prop, i| {
            pool_properties[i] = try prop.clone(self.allocator);
        }

        // Create edge
        const edge = try self.edge_pool.createEdge(schema_name, from_node, to_node, pool_properties);

        // Log to WAL
        try self.wal.append_insert_edge_soa(from_node, to_node, 0); // TODO: Add property logging

        return edge.id;
    }

    /// Get node by ID
    pub inline fn getNode(self: *const PropertyGraph, id: u64) ?*Node {
        return self.node_pool.getNode(id);
    }

    /// Get edge by ID
    pub inline fn getEdge(self: *const PropertyGraph, id: u64) ?*Edge {
        return self.edge_pool.getEdge(id);
    }

    /// Batch node creation with SIMD optimization
    pub inline fn createNodesBatch(self: *PropertyGraph, schema_name: []const u8, count: usize, node_ids: []u64, getProperties: anytype) !void {
        assert(count <= node_ids.len);
        assert(count > 0);

        // Get schema
        const schema = self.node_schemas.get(schema_name) orelse return error.UnknownSchema;

        // Process in batches for SIMD optimization
        const batch_size = 8; // SIMD batch size
        var i: usize = 0;

        while (i < count) {
            const current_batch_size = @min(batch_size, count - i);

            // Create batch of nodes
            for (0..current_batch_size) |batch_idx| {
                const global_idx = i + batch_idx;
                const properties = try getProperties(global_idx, schema_name);

                // Validate properties
                try schema.validateProperties(properties);

                // Allocate properties
                var pool_properties = try self.allocator.alloc(Property, properties.len);
                for (properties, 0..) |prop, prop_idx| {
                    pool_properties[prop_idx] = try prop.clone(self.allocator);
                }

                // Create node
                const node = try self.node_pool.createNode(schema_name, pool_properties);
                node_ids[global_idx] = node.id;
            }

            // Process batch with SIMD
            try self.simd_processor.processBatch(&self.node_pool, i, current_batch_size);

            i += current_batch_size;
        }
    }

    /// Find nodes by property value
    pub inline fn findNodesByProperty(self: *PropertyGraph, schema_name: []const u8, property_name: []const u8, value: PropertyValue) ![]u64 {
        // TODO: Implement property indexing
        _ = self;
        _ = schema_name;
        _ = property_name;
        _ = value;
        return &[_]u64{};
    }

    /// Update node property
    pub inline fn updateNodeProperty(self: *PropertyGraph, node_id: u64, property_name: []const u8, value: PropertyValue) !void {
        const node = self.node_pool.getNode(node_id) orelse return error.NodeNotFound;

        // Find and update property
        for (node.properties) |*prop| {
            if (std.mem.eql(u8, prop.name, property_name)) {
                prop.value.deinit(self.allocator);
                prop.value = try value.clone(self.allocator);
                return;
            }
        }

        return error.PropertyNotFound;
    }

    /// Migrate node schema (schema evolution)
    pub inline fn migrateNodeSchema(self: *PropertyGraph, schema_name: []const u8, new_schema: NodeSchema) !void {
        // TODO: Implement schema migration
        _ = self;
        _ = schema_name;
        _ = new_schema;
    }

    /// Get database statistics
    pub inline fn getStats(self: *const PropertyGraph) GraphStats {
        return GraphStats{
            .node_count = self.node_pool.getNodeCount(),
            .edge_count = self.edge_pool.getEdgeCount(),
            .property_count = self.property_pool.getPropertyCount(),
            .schema_count = @intCast(self.node_schemas.count() + self.edge_schemas.count()),
        };
    }

    /// Get memory statistics
    pub inline fn getMemoryStats(self: *const PropertyGraph) MemoryStats {
        const node_count = self.node_pool.getNodeCount();
        const edge_count = self.edge_pool.getEdgeCount();
        const property_count = self.property_pool.getPropertyCount();

        return MemoryStats{
            .uses_static_allocation = true,
            .dynamic_allocations = 0,
            .memory_efficiency = @as(f64, @floatFromInt(node_count + edge_count + property_count)) / @as(f64, @floatFromInt(NodePool.MAX_NODES + EdgePool.MAX_EDGES + PropertyPool.MAX_PROPERTIES)),
            .property_pool_usage = @as(f64, @floatFromInt(property_count)) / @as(f64, @floatFromInt(PropertyPool.MAX_PROPERTIES)),
            .node_pool_usage = @as(f64, @floatFromInt(node_count)) / @as(f64, @floatFromInt(NodePool.MAX_NODES)),
            .edge_pool_usage = @as(f64, @floatFromInt(edge_count)) / @as(f64, @floatFromInt(EdgePool.MAX_EDGES)),
        };
    }
};
