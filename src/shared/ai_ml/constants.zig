//! AI/ML Constants for NenDB
//!
//! Defines constants used in AI/ML operations, vector embeddings,
//! and machine learning algorithms.

const std = @import("std");

// Vector embedding constants
pub const DEFAULT_EMBEDDING_DIMENSIONS = 128;
pub const MAX_EMBEDDING_DIMENSIONS = 4096;
pub const MIN_EMBEDDING_DIMENSIONS = 8;

// GNN (Graph Neural Network) constants
pub const DEFAULT_GNN_LAYERS = 3;
pub const MAX_GNN_LAYERS = 10;
pub const DEFAULT_GNN_HIDDEN_SIZE = 64;

// Knowledge graph constants
pub const DEFAULT_ENTITY_TYPES = 10;
pub const DEFAULT_RELATION_TYPES = 20;
pub const MAX_ENTITY_TYPES = 1000;
pub const MAX_RELATION_TYPES = 1000;

// Vector similarity thresholds
pub const COSINE_SIMILARITY_THRESHOLD = 0.7;
pub const EUCLIDEAN_DISTANCE_THRESHOLD = 0.5;

// Batch processing constants
pub const DEFAULT_BATCH_SIZE = 32;
pub const MAX_BATCH_SIZE = 1024;
pub const MIN_BATCH_SIZE = 1;

// Learning rate constants
pub const DEFAULT_LEARNING_RATE = 0.001;
pub const MIN_LEARNING_RATE = 0.0001;
pub const MAX_LEARNING_RATE = 0.1;

// Training constants
pub const DEFAULT_EPOCHS = 100;
pub const MAX_EPOCHS = 10000;
pub const DEFAULT_EARLY_STOPPING_PATIENCE = 10;

// Memory allocation constants
pub const DEFAULT_EMBEDDING_POOL_SIZE = 10000;
pub const DEFAULT_VECTOR_CACHE_SIZE = 1000;

// Performance constants
pub const SIMD_VECTOR_SIZE = 4; // For f32 vectors
pub const PARALLEL_THREADS = 4;

// Error codes
pub const ErrorCode = enum(u32) {
    invalid_dimensions = 1,
    embedding_not_found = 2,
    vector_mismatch = 3,
    batch_size_invalid = 4,
    learning_rate_invalid = 5,
    gnn_layer_invalid = 6,
    similarity_calculation_failed = 7,
    memory_allocation_failed = 8,
    training_failed = 9,
    prediction_failed = 10,
};

// Utility functions
pub fn isValidEmbeddingDimensions(dims: u32) bool {
    return dims >= MIN_EMBEDDING_DIMENSIONS and dims <= MAX_EMBEDDING_DIMENSIONS;
}

pub fn isValidBatchSize(size: u32) bool {
    return size >= MIN_BATCH_SIZE and size <= MAX_BATCH_SIZE;
}

pub fn isValidLearningRate(rate: f32) bool {
    return rate >= MIN_LEARNING_RATE and rate <= MAX_LEARNING_RATE;
}

pub fn isValidGnnLayers(layers: u32) bool {
    return layers >= 1 and layers <= MAX_GNN_LAYERS;
}
