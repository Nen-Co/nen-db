// NenDB Production - No WAL Version (for testing)
// Following TigerBeetle's architecture for mission-critical performance

const std = @import("std");
const constants = @import("constants.zig");
const pool = @import("memory/pool_v2.zig");

// Batch operation definitions (TigerBeetle-style fixed structs)
pub const NodeDef = extern struct { 
    id: u64,  // Changed to u64 for performance
    kind: u8, 
    reserved: [7]u8 = [_]u8{0} ** 7,
    props: [constants.data.node_props_size]u8 = [_]u8{0} ** constants.data.node_props_size,
};

pub const EdgeDef = extern struct { 
    from: u64,  // Node IDs instead of string references
    to: u64, 
    label: u16, 
    reserved: [6]u8 = [_]u8{0} ** 6,
    props: [constants.data.edge_props_size]u8 = [_]u8{0} ** constants.data.edge_props_size,
};

pub const EmbeddingDef = extern struct {
    node_id: u64,
    reserved: [8]u8 = [_]u8{0} ** 8,
    vector: [constants.data.embedding_dimensions]f32,
};

// Batch insert structures (TigerBeetle batch pattern)
pub const BatchNodeInsert = struct {
    nodes: []const NodeDef,
};

pub const BatchEdgeInsert = struct {
    edges: []const EdgeDef,
};

pub const BatchEmbeddingInsert = struct {
    embeddings: []const EmbeddingDef,
};

// Result structures
pub const BatchResult = struct {
    success_count: u32,
    error_count: u32,
    errors: []constants.NenDBError,
};

// Memory statistics for monitoring
pub const DatabaseStats = struct {
    nodes: pool.MemoryStats,
    edges: pool.MemoryStats,
    embeddings: pool.MemoryStats,
    total_memory_bytes: u64,
    operations_count: u64,
};

// The main NenDB engine (production-ready, no WAL for now)
pub const NenDB = struct {
    const Self = @This();
    
    // Static memory pools (zero dynamic allocation)
    node_pool: pool.NodePool,
    edge_pool: pool.EdgePool,
    embedding_pool: pool.EmbeddingPool,
    
    // Configuration
    allocator: std.mem.Allocator,
    data_dir: []const u8,
    
    // Statistics
    operations_count: u64 = 0,
    
    pub fn init(allocator: std.mem.Allocator, data_dir: []const u8) !Self {
        const self = Self{
            .node_pool = pool.NodePool.init(),
            .edge_pool = pool.EdgePool.init(),
            .embedding_pool = pool.EmbeddingPool.init(),
            .allocator = allocator,
            .data_dir = data_dir,
        };
        
        // Create data directory if it doesn't exist
        std.fs.cwd().makeDir(data_dir) catch |err| switch (err) {
            error.PathAlreadyExists => {},
            else => return err,
        };
        
        std.log.info("NenDB initialized without WAL (production testing)", .{});
        
        return self;
    }
    
    pub fn deinit(self: *Self) void {
        _ = self; // Nothing to clean up with static allocation
    }
    
    // TigerBeetle-style batch operations
    pub fn batch_insert_nodes(self: *Self, batch: BatchNodeInsert) !BatchResult {
        var success_count: u32 = 0;
        var error_count: u32 = 0;
        
        for (batch.nodes) |node_def| {
            const node = pool.Node{
                .id = node_def.id,
                .kind = node_def.kind,
                .props = node_def.props,
            };
            
            if (self.node_pool.alloc(node)) |_| {
                success_count += 1;
                self.operations_count += 1;
            } else |_| {
                error_count += 1;
            }
        }
        
        return BatchResult{
            .success_count = success_count,
            .error_count = error_count,
            .errors = &[_]constants.NenDBError{}, // Empty slice for now
        };
    }
    
    pub fn batch_insert_edges(self: *Self, batch: BatchEdgeInsert) !BatchResult {
        var success_count: u32 = 0;
        var error_count: u32 = 0;
        
        for (batch.edges) |edge_def| {
            // Validate that nodes exist
            if (self.node_pool.get_by_id(edge_def.from) == null) {
                error_count += 1;
                continue;
            }
            
            if (self.node_pool.get_by_id(edge_def.to) == null) {
                error_count += 1;
                continue;
            }
            
            const edge = pool.Edge{
                .from = edge_def.from,
                .to = edge_def.to,
                .label = edge_def.label,
                .props = edge_def.props,
            };
            
            if (self.edge_pool.alloc(edge)) |_| {
                success_count += 1;
                self.operations_count += 1;
            } else |_| {
                error_count += 1;
            }
        }
        
        return BatchResult{
            .success_count = success_count,
            .error_count = error_count,
            .errors = &[_]constants.NenDBError{}, // Empty slice for now
        };
    }
    
    // AI-optimized context assembly (NenDB's killer feature)
    pub fn assemble_context(self: *const Self, start_node_id: u64, buffer: []u8) !usize {
        var context_len: usize = 0;
        
        // Find the starting node
        const start_node = self.node_pool.get_by_id(start_node_id) orelse return constants.NenDBError.NodeNotFound;
        
        // Add starting node to context
        const node_context = try std.fmt.bufPrint(
            buffer[context_len..],
            "Node {d}: kind={d}, props=\"{s}\"\n",
            .{ start_node.id, start_node.kind, std.mem.sliceTo(&start_node.props, 0) }
        );
        context_len += node_context.len;
        
        // Find all edges from this node (simple traversal for now)
        for (0..self.edge_pool.used_count) |i| {
            const edge = self.edge_pool.get(@intCast(i)) orelse continue;
            
            if (edge.from == start_node_id) {
                // Add edge to context
                const edge_context = try std.fmt.bufPrint(
                    buffer[context_len..],
                    "Edge {d}->{d}: label={d}\n",
                    .{ edge.from, edge.to, edge.label }
                );
                context_len += edge_context.len;
                
                // Add target node
                if (self.node_pool.get_by_id(edge.to)) |target_node| {
                    const target_context = try std.fmt.bufPrint(
                        buffer[context_len..],
                        "Connected Node {d}: kind={d}\n",
                        .{ target_node.id, target_node.kind }
                    );
                    context_len += target_context.len;
                }
            }
        }
        
        return context_len;
    }
    
    pub fn get_stats(self: *const Self) DatabaseStats {
        const node_stats = self.node_pool.get_stats();
        const edge_stats = self.edge_pool.get_stats();
        const embedding_stats = self.embedding_pool.get_stats();
        
        // Calculate total memory (static allocation means this is constant!)
        const total_memory = @sizeOf(Self);
        
        return DatabaseStats{
            .nodes = node_stats,
            .edges = edge_stats,
            .embeddings = embedding_stats,
            .total_memory_bytes = total_memory,
            .operations_count = self.operations_count,
        };
    }
    
    // Placeholder checkpoint (no WAL)
    pub fn checkpoint(self: *Self) !void {
        _ = self;
        std.log.info("Checkpoint called (no WAL implementation)", .{});
    }
};
