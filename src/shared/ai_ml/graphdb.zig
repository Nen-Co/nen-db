//! GraphDB integration for AI/ML operations
//! 
//! Provides AI/ML specific extensions to the core GraphDB functionality.

const std = @import("std");
const constants = @import("constants.zig");

// Re-export the core GraphDB from shared
pub const GraphDB = @import("../core/graphdb.zig").GraphDB;

// AI/ML specific extensions to GraphDB
pub const AIGraphDB = struct {
    graphdb: GraphDB,
    allocator: std.mem.Allocator,
    
    // AI/ML specific data
    embeddings: std.ArrayList(f32),
    embedding_dimensions: u32,
    entity_types: std.ArrayList([]const u8),
    relation_types: std.ArrayList([]const u8),
    
    pub fn init(allocator: std.mem.Allocator, embedding_dims: u32) !@This() {
        return AIGraphDB{
            .graphdb = try GraphDB.init(allocator),
            .allocator = allocator,
            .embeddings = std.ArrayList(f32).init(allocator),
            .embedding_dimensions = embedding_dims,
            .entity_types = std.ArrayList([]const u8).init(allocator),
            .relation_types = std.ArrayList([]const u8).init(allocator),
        };
    }
    
    pub fn deinit(self: *@This()) void {
        self.graphdb.deinit();
        self.embeddings.deinit();
        self.entity_types.deinit();
        self.relation_types.deinit();
    }
    
    // AI/ML specific methods
    pub fn addEntityType(self: *@This(), entity_type: []const u8) !void {
        try self.entity_types.append(entity_type);
    }
    
    pub fn addRelationType(self: *@This(), relation_type: []const u8) !void {
        try self.relation_types.append(relation_type);
    }
    
    pub fn addEmbedding(self: *@This(), embedding: []const f32) !void {
        if (embedding.len != self.embedding_dimensions) {
            return error.InvalidEmbeddingDimensions;
        }
        try self.embeddings.appendSlice(embedding);
    }
    
    pub fn getEmbedding(self: *@This(), index: u32) ?[]const f32 {
        if (index * self.embedding_dimensions >= self.embeddings.items.len) {
            return null;
        }
        const start = index * self.embedding_dimensions;
        const end = start + self.embedding_dimensions;
        return self.embeddings.items[start..end];
    }
    
    pub fn getEntityType(self: *@This(), index: u32) ?[]const u8 {
        if (index >= self.entity_types.items.len) {
            return null;
        }
        return self.entity_types.items[index];
    }
    
    pub fn getRelationType(self: *@This(), index: u32) ?[]const u8 {
        if (index >= self.relation_types.items.len) {
            return null;
        }
        return self.relation_types.items[index];
    }
    
    pub fn getEmbeddingCount(self: *@This()) u32 {
        return @as(u32, @intCast(self.embeddings.items.len / self.embedding_dimensions));
    }
    
    pub fn getEntityTypeCount(self: *@This()) u32 {
        return @as(u32, @intCast(self.entity_types.items.len));
    }
    
    pub fn getRelationTypeCount(self: *@This()) u32 {
        return @as(u32, @intCast(self.relation_types.items.len));
    }
};

// Error types
pub const Error = error{
    InvalidEmbeddingDimensions,
    EmbeddingNotFound,
    VectorMismatch,
    MemoryAllocationFailed,
};
