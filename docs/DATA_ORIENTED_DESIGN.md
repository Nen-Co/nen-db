# NenDB Data-Oriented Design (DOD) Architecture

## Overview

NenDB implements a **Data-Oriented Design (DOD)** paradigm, prioritizing data layout and memory access patterns over traditional object-oriented abstractions. This approach maximizes performance, cache efficiency, and scalability for graph database operations.

## Core DOD Principles

### 1. **Struct of Arrays (SoA) over Array of Structs (AoS)**
Instead of storing related data together in objects, we separate data by type into parallel arrays.

**Traditional AoS (❌ Inefficient):**
```zig
pub const Node = struct {
    id: u64,
    kind: u8,
    props: [128]u8,
    active: bool,
};
nodes: [NODE_POOL_SIZE]Node,
```

**DOD SoA (✅ Efficient):**
```zig
pub const NodeData = struct {
    ids: [NODE_POOL_SIZE]u64,
    kinds: [NODE_POOL_SIZE]u8,
    props: [NODE_POOL_SIZE][128]u8,
    active: [NODE_POOL_SIZE]bool,
};
```

### 2. **Hot/Cold Data Separation**
Frequently accessed data is separated from rarely accessed data to improve cache locality.

**Hot Data (accessed frequently):**
- Node IDs, kinds, active status
- Edge endpoints, labels
- Adjacency lists

**Cold Data (accessed rarely):**
- Large property blobs
- Metadata and timestamps
- Debug information

### 3. **Component-Based Architecture**
Graph entities are composed of components rather than monolithic structures.

```zig
pub const GraphComponents = struct {
    // Core entity data
    positions: [MAX_ENTITIES]Vec3,
    relationships: [MAX_ENTITIES]RelationshipData,
    
    // AI/ML components
    embeddings: [MAX_ENTITIES]EmbeddingVector,
    ml_features: [MAX_ENTITIES]MLFeatures,
    
    // Property components
    properties: [MAX_ENTITIES]PropertyMap,
};
```

### 4. **SIMD-Optimized Layouts**
Data is organized for vectorized operations and SIMD instructions.

```zig
pub const SIMDNodeData = struct {
    // Aligned for SIMD operations
    ids: [NODE_POOL_SIZE]u64 align(32),
    kinds: [NODE_POOL_SIZE]u8 align(32),
    
    // Bit masks for efficient filtering
    active_mask: [NODE_POOL_SIZE / 8]u8,
    dirty_mask: [NODE_POOL_SIZE / 8]u8,
};
```

## NenDB DOD Implementation

### Core Data Structures

```zig
pub const GraphData = struct {
    // Node data in SoA format
    node_ids: [NODE_POOL_SIZE]u64,
    node_kinds: [NODE_POOL_SIZE]u8,
    node_active: [NODE_POOL_SIZE]bool,
    node_generation: [NODE_POOL_SIZE]u32,
    
    // Edge data in SoA format
    edge_from: [EDGE_POOL_SIZE]u64,
    edge_to: [EDGE_POOL_SIZE]u64,
    edge_labels: [EDGE_POOL_SIZE]u16,
    edge_active: [EDGE_POOL_SIZE]bool,
    edge_generation: [EDGE_POOL_SIZE]u32,
    
    // Embedding data
    embedding_node_ids: [EMBEDDING_POOL_SIZE]u64,
    embedding_vectors: [EMBEDDING_POOL_SIZE][EMBEDDING_DIM]f32,
    embedding_active: [EMBEDDING_POOL_SIZE]bool,
    
    // Property storage (cold data)
    node_properties: [NODE_POOL_SIZE]PropertyBlock,
    edge_properties: [EDGE_POOL_SIZE]PropertyBlock,
    
    // Index structures for fast lookups
    node_index: NodeIndex,
    edge_index: EdgeIndex,
    embedding_index: EmbeddingIndex,
};
```

### Component System

```zig
pub const ComponentSystem = struct {
    // Position components for spatial queries
    positions: [MAX_ENTITIES]Vec3,
    velocities: [MAX_ENTITIES]Vec3,
    
    // Relationship components
    parent_relationships: [MAX_ENTITIES]ParentData,
    sibling_relationships: [MAX_ENTITIES]SiblingData,
    
    // AI/ML components
    embeddings: [MAX_ENTITIES]EmbeddingVector,
    attention_weights: [MAX_ENTITIES]AttentionData,
    ml_predictions: [MAX_ENTITIES]MLPrediction,
    
    // Property components
    string_properties: [MAX_ENTITIES]StringPropertyMap,
    numeric_properties: [MAX_ENTITIES]NumericPropertyMap,
    boolean_properties: [MAX_ENTITIES]BooleanPropertyMap,
};
```

### Batch Processing with DOD

```zig
pub const DODBatchProcessor = struct {
    // Process nodes in batches for better cache usage
    pub fn processNodeBatch(
        node_data: *NodeData,
        operation: NodeOperation,
        batch_size: u32
    ) void {
        // Vectorized operations on node arrays
        for (0..batch_size) |i| {
            if (node_data.active[i]) {
                operation.process(&node_data.ids[i], &node_data.kinds[i]);
            }
        }
    }
    
    // SIMD-optimized filtering
    pub fn filterNodesByKind(
        node_data: *const NodeData,
        kind: u8,
        result_indices: []u32
    ) u32 {
        var count: u32 = 0;
        for (node_data.kinds, 0..) |node_kind, i| {
            if (node_kind == kind and node_data.active[i]) {
                result_indices[count] = @intCast(i);
                count += 1;
            }
        }
        return count;
    }
};
```

## Performance Benefits

### 1. **Cache Locality**
- SoA layout keeps related data together
- Hot/cold separation reduces cache misses
- Sequential access patterns improve prefetching

### 2. **SIMD Optimization**
- Vectorized operations on arrays
- Aligned data structures for SIMD instructions
- Bit manipulation for efficient filtering

### 3. **Memory Bandwidth**
- Only load needed data
- Reduced memory fragmentation
- Better memory access patterns

### 4. **Scalability**
- Component-based architecture scales better
- Parallel processing of independent components
- Reduced contention on shared data

## Graph Algorithm Optimization

### Traversal Optimization
```zig
pub const GraphTraversal = struct {
    // Adjacency data optimized for traversal
    adjacency_lists: [MAX_NODES]AdjacencyList,
    
    // Pre-computed indices for different traversal patterns
    bfs_data: BFSData,
    dfs_data: DFSData,
    shortest_path_data: ShortestPathData,
    
    // SIMD-optimized traversal
    pub fn traverseBFS(
        start_node: u64,
        max_depth: u32,
        visitor: *TraversalVisitor
    ) void {
        // Vectorized BFS implementation
    }
};
```

### Query Optimization
```zig
pub const QueryEngine = struct {
    // Index structures for fast lookups
    node_by_kind: [MAX_KINDS]NodeIndex,
    edges_by_label: [MAX_LABELS]EdgeIndex,
    spatial_index: SpatialIndex,
    
    // SIMD-optimized query execution
    pub fn executeQuery(query: *Query) QueryResult {
        // Vectorized query processing
    }
};
```

## Memory Management

### Static Allocation
- Pre-allocated pools for all data types
- No dynamic allocation during operations
- Predictable memory usage

### Memory Pools
```zig
pub const MemoryPools = struct {
    node_pool: NodeData,
    edge_pool: EdgeData,
    embedding_pool: EmbeddingData,
    property_pool: PropertyData,
    
    // Pool statistics
    stats: PoolStatistics,
    
    // Memory optimization
    pub fn defragment() void {
        // Defragment pools for better locality
    }
};
```

## Implementation Guidelines

### 1. **Data Layout Rules**
- Group data by access frequency
- Align structures for SIMD operations
- Use power-of-2 sizes for better alignment

### 2. **Algorithm Design**
- Process data in batches
- Use vectorized operations where possible
- Minimize pointer chasing

### 3. **Memory Access Patterns**
- Sequential access over random access
- Prefetch data for next operations
- Cache-friendly data structures

### 4. **Performance Monitoring**
- Track cache hit rates
- Monitor memory bandwidth usage
- Profile SIMD utilization

## Migration Strategy

### Phase 1: Core SoA Implementation
- Convert Node/Edge structures to SoA
- Implement basic component system
- Update batch processing

### Phase 2: Hot/Cold Separation
- Separate frequently accessed data
- Implement property storage system
- Optimize memory layout

### Phase 3: SIMD Optimization
- Add SIMD-friendly layouts
- Implement vectorized operations
- Optimize critical paths

### Phase 4: Advanced Features
- Component-based architecture
- Advanced indexing
- Performance monitoring

## Conclusion

Data-Oriented Design is the foundation of NenDB's high-performance architecture. By prioritizing data layout and memory access patterns, we achieve:

- **Maximum Performance**: Optimized for modern hardware
- **Predictable Behavior**: Static allocation and deterministic access patterns
- **Scalability**: Component-based architecture scales with data size
- **Maintainability**: Clear separation of concerns and data flow

This paradigm shift from object-oriented to data-oriented design positions NenDB as a truly high-performance graph database optimized for AI/ML workloads.
