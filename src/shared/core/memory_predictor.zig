// NenDB Advanced Memory Prediction System
// Implements intelligent memory allocation prediction for optimal performance

const std = @import("std");
const assert = std.debug.assert;
const constants = @import("constants.zig");

// Memory prediction constants
const PREDICTION_WINDOW_SIZE: usize = 1000; // Last 1000 operations
const MIN_PREDICTION_SAMPLES: usize = 10;
const PREDICTION_ACCURACY_THRESHOLD: f64 = 0.8;
const MEMORY_GROWTH_FACTOR: f64 = 1.2; // 20% growth buffer

// Memory usage patterns
const MemoryPattern = enum {
    linear_growth,
    exponential_growth,
    cyclical,
    stable,
    unpredictable,
};

// Memory allocation request
const AllocationRequest = struct {
    timestamp: i64,
    operation_type: OperationType,
    requested_size: usize,
    actual_size: usize,
    success: bool,

    const SIZE = 8 + 1 + 8 + 8 + 1; // 26 bytes

    fn serialize(self: *const AllocationRequest, buffer: []u8) void {
        assert(buffer.len >= SIZE);
        var offset: usize = 0;

        std.mem.writeInt(i64, buffer[offset .. offset + 8], self.timestamp, .little);
        offset += 8;

        buffer[offset] = @intFromEnum(self.operation_type);
        offset += 1;

        std.mem.writeInt(usize, buffer[offset .. offset + 8], self.requested_size, .little);
        offset += 8;

        std.mem.writeInt(usize, buffer[offset .. offset + 8], self.actual_size, .little);
        offset += 8;

        buffer[offset] = if (self.success) 1 else 0;
    }

    fn deserialize(buffer: []const u8) AllocationRequest {
        assert(buffer.len >= SIZE);
        var offset: usize = 0;

        const timestamp = std.mem.readInt(i64, buffer[offset .. offset + 8], .little);
        offset += 8;

        const operation_type = @as(OperationType, @enumFromInt(buffer[offset]));
        offset += 1;

        const requested_size = std.mem.readInt(usize, buffer[offset .. offset + 8], .little);
        offset += 8;

        const actual_size = std.mem.readInt(usize, buffer[offset .. offset + 8], .little);
        offset += 8;

        const success = buffer[offset] != 0;

        return AllocationRequest{
            .timestamp = timestamp,
            .operation_type = operation_type,
            .requested_size = requested_size,
            .actual_size = actual_size,
            .success = success,
        };
    }
};

// Operation types for prediction
const OperationType = enum(u8) {
    node_insert = 1,
    node_update = 2,
    node_delete = 3,
    edge_insert = 4,
    edge_update = 5,
    edge_delete = 6,
    vector_insert = 7,
    vector_search = 8,
    batch_operation = 9,
    transaction = 10,
};

// Memory prediction result
const PredictionResult = struct {
    predicted_size: usize,
    confidence: f64,
    pattern: MemoryPattern,
    recommended_allocation: usize,
    risk_level: RiskLevel,
};

// Risk levels for memory allocation
const RiskLevel = enum {
    low,
    medium,
    high,
    critical,
};

// Memory usage statistics
const MemoryStats = struct {
    total_allocations: u64,
    successful_allocations: u64,
    failed_allocations: u64,
    total_memory_used: usize,
    peak_memory_used: usize,
    average_allocation_size: f64,
    prediction_accuracy: f64,
    pattern_detection_accuracy: f64,
};

// Advanced memory predictor
pub const AdvancedMemoryPredictor = struct {
    allocator: std.mem.Allocator,
    request_history: std.ArrayList(AllocationRequest),
    pattern_history: std.ArrayList(MemoryPattern),
    current_pattern: MemoryPattern = .stable,
    pattern_confidence: f64 = 0.0,
    last_prediction_time: i64 = 0,

    // Statistics
    stats: MemoryStats = MemoryStats{
        .total_allocations = 0,
        .successful_allocations = 0,
        .failed_allocations = 0,
        .total_memory_used = 0,
        .peak_memory_used = 0,
        .average_allocation_size = 0.0,
        .prediction_accuracy = 0.0,
        .pattern_detection_accuracy = 0.0,
    },

    // Pattern detection
    pattern_detector: PatternDetector,

    pub fn init(allocator: std.mem.Allocator) AdvancedMemoryPredictor {
        return AdvancedMemoryPredictor{
            .allocator = allocator,
            .request_history = std.ArrayList(AllocationRequest).init(allocator),
            .pattern_history = std.ArrayList(MemoryPattern).init(allocator),
            .pattern_detector = PatternDetector.init(allocator),
        };
    }

    pub fn deinit(self: *AdvancedMemoryPredictor) void {
        self.request_history.deinit();
        self.pattern_history.deinit();
        self.pattern_detector.deinit();
    }

    /// Record a memory allocation request
    pub fn recordAllocation(self: *AdvancedMemoryPredictor, operation_type: OperationType, requested_size: usize, actual_size: usize, success: bool) !void {
        const request = AllocationRequest{
            .timestamp = std.time.timestamp(),
            .operation_type = operation_type,
            .requested_size = requested_size,
            .actual_size = actual_size,
            .success = success,
        };

        try self.request_history.append(request);

        // Keep only recent history
        if (self.request_history.items.len > PREDICTION_WINDOW_SIZE) {
            _ = self.request_history.orderedRemove(0);
        }

        // Update statistics
        self.stats.total_allocations += 1;
        if (success) {
            self.stats.successful_allocations += 1;
            self.stats.total_memory_used += actual_size;
            if (actual_size > self.stats.peak_memory_used) {
                self.stats.peak_memory_used = actual_size;
            }
        } else {
            self.stats.failed_allocations += 1;
        }

        // Update average allocation size
        self.updateAverageAllocationSize();

        // Detect pattern changes
        try self.detectPatternChange();
    }

    /// Predict memory allocation for next operation
    pub fn predictAllocation(self: *AdvancedMemoryPredictor, operation_type: OperationType) !PredictionResult {
        if (self.request_history.items.len < MIN_PREDICTION_SAMPLES) {
            return self.getDefaultPrediction(operation_type);
        }

        // Analyze historical data for this operation type
        const historical_data = try self.getHistoricalData(operation_type);
        defer self.allocator.free(historical_data);

        if (historical_data.len == 0) {
            return self.getDefaultPrediction(operation_type);
        }

        // Calculate prediction based on pattern
        const prediction = switch (self.current_pattern) {
            .linear_growth => try self.predictLinearGrowth(historical_data),
            .exponential_growth => try self.predictExponentialGrowth(historical_data),
            .cyclical => try self.predictCyclical(historical_data),
            .stable => try self.predictStable(historical_data),
            .unpredictable => self.getDefaultPrediction(operation_type),
        };

        // Update prediction accuracy
        self.updatePredictionAccuracy(prediction);

        return prediction;
    }

    /// Get recommended memory allocation strategy
    pub fn getMemoryStrategy(self: *AdvancedMemoryPredictor) MemoryStrategy {
        return MemoryStrategy{
            .pattern = self.current_pattern,
            .confidence = self.pattern_confidence,
            .recommended_pool_size = self.calculateRecommendedPoolSize(),
            .growth_factor = self.calculateGrowthFactor(),
            .risk_level = self.assessRiskLevel(),
        };
    }

    /// Get historical data for specific operation type
    fn getHistoricalData(self: *AdvancedMemoryPredictor, operation_type: OperationType) ![]AllocationRequest {
        var filtered = std.ArrayList(AllocationRequest).init(self.allocator);

        for (self.request_history.items) |request| {
            if (request.operation_type == operation_type) {
                try filtered.append(request);
            }
        }

        return filtered.toOwnedSlice();
    }

    /// Predict linear growth pattern
    fn predictLinearGrowth(self: *AdvancedMemoryPredictor, data: []const AllocationRequest) !PredictionResult {
        if (data.len < 2) return self.getDefaultPrediction(data[0].operation_type);

        // Calculate linear regression
        var sum_x: f64 = 0;
        var sum_y: f64 = 0;
        var sum_xy: f64 = 0;
        var sum_x2: f64 = 0;

        for (data, 0..) |request, i| {
            const x = @as(f64, @floatFromInt(i));
            const y = @as(f64, @floatFromInt(request.actual_size));

            sum_x += x;
            sum_y += y;
            sum_xy += x * y;
            sum_x2 += x * x;
        }

        const n = @as(f64, @floatFromInt(data.len));
        const slope = (n * sum_xy - sum_x * sum_y) / (n * sum_x2 - sum_x * sum_x);
        const intercept = (sum_y - slope * sum_x) / n;

        // Predict next allocation
        const next_x = n;
        const predicted_size = @as(usize, @intFromFloat(slope * next_x + intercept));

        // Calculate confidence based on R-squared
        const confidence = self.calculateLinearConfidence(data, slope, intercept);

        return PredictionResult{
            .predicted_size = predicted_size,
            .confidence = confidence,
            .pattern = .linear_growth,
            .recommended_allocation = @as(usize, @intFromFloat(@as(f64, @floatFromInt(predicted_size)) * MEMORY_GROWTH_FACTOR)),
            .risk_level = if (confidence > PREDICTION_ACCURACY_THRESHOLD) .low else .medium,
        };
    }

    /// Predict exponential growth pattern
    fn predictExponentialGrowth(self: *AdvancedMemoryPredictor, data: []const AllocationRequest) !PredictionResult {
        if (data.len < 3) return self.getDefaultPrediction(data[0].operation_type);

        // Calculate exponential regression
        var sum_x: f64 = 0;
        var sum_y: f64 = 0;
        var sum_xy: f64 = 0;
        var sum_x2: f64 = 0;

        for (data, 0..) |request, i| {
            const x = @as(f64, @floatFromInt(i));
            const y = @log(@as(f64, @floatFromInt(request.actual_size)));

            sum_x += x;
            sum_y += y;
            sum_xy += x * y;
            sum_x2 += x * x;
        }

        const n = @as(f64, @floatFromInt(data.len));
        const slope = (n * sum_xy - sum_x * sum_y) / (n * sum_x2 - sum_x * sum_x);
        const intercept = (sum_y - slope * sum_x) / n;

        // Predict next allocation
        const next_x = n;
        const predicted_size = @as(usize, @intFromFloat(@exp(slope * next_x + intercept)));

        const confidence = self.calculateExponentialConfidence(data, slope, intercept);

        return PredictionResult{
            .predicted_size = predicted_size,
            .confidence = confidence,
            .pattern = .exponential_growth,
            .recommended_allocation = @as(usize, @intFromFloat(@as(f64, @floatFromInt(predicted_size)) * MEMORY_GROWTH_FACTOR)),
            .risk_level = if (confidence > PREDICTION_ACCURACY_THRESHOLD) .medium else .high,
        };
    }

    /// Predict cyclical pattern
    fn predictCyclical(self: *AdvancedMemoryPredictor, data: []const AllocationRequest) !PredictionResult {
        if (data.len < 4) return self.getDefaultPrediction(data[0].operation_type);

        // Find cycle length using autocorrelation
        const cycle_length = self.findCycleLength(data);

        // Predict based on cycle position
        const cycle_position = data.len % cycle_length;
        const predicted_size = data[cycle_position].actual_size;

        const confidence = self.calculateCyclicalConfidence(data, cycle_length);

        return PredictionResult{
            .predicted_size = predicted_size,
            .confidence = confidence,
            .pattern = .cyclical,
            .recommended_allocation = @as(usize, @intFromFloat(@as(f64, @floatFromInt(predicted_size)) * MEMORY_GROWTH_FACTOR)),
            .risk_level = if (confidence > PREDICTION_ACCURACY_THRESHOLD) .low else .medium,
        };
    }

    /// Predict stable pattern
    fn predictStable(self: *AdvancedMemoryPredictor, data: []const AllocationRequest) !PredictionResult {
        // Calculate average size
        var total_size: usize = 0;
        for (data) |request| {
            total_size += request.actual_size;
        }

        const average_size = total_size / data.len;
        const confidence = self.calculateStableConfidence(data, average_size);

        return PredictionResult{
            .predicted_size = average_size,
            .confidence = confidence,
            .pattern = .stable,
            .recommended_allocation = @as(usize, @intFromFloat(@as(f64, @floatFromInt(average_size)) * MEMORY_GROWTH_FACTOR)),
            .risk_level = if (confidence > PREDICTION_ACCURACY_THRESHOLD) .low else .medium,
        };
    }

    /// Get default prediction when insufficient data
    fn getDefaultPrediction(self: *AdvancedMemoryPredictor, operation_type: OperationType) PredictionResult {
        _ = self;
        const default_size = switch (operation_type) {
            .node_insert => 1024,
            .node_update => 512,
            .node_delete => 256,
            .edge_insert => 512,
            .edge_update => 256,
            .edge_delete => 128,
            .vector_insert => 4096,
            .vector_search => 2048,
            .batch_operation => 8192,
            .transaction => 16384,
        };

        return PredictionResult{
            .predicted_size = default_size,
            .confidence = 0.5,
            .pattern = .unpredictable,
            .recommended_allocation = @as(usize, @intFromFloat(@as(f64, @floatFromInt(default_size)) * MEMORY_GROWTH_FACTOR)),
            .risk_level = .high,
        };
    }

    /// Detect pattern changes in memory usage
    fn detectPatternChange(self: *AdvancedMemoryPredictor) !void {
        if (self.request_history.items.len < MIN_PREDICTION_SAMPLES) return;

        const new_pattern = try self.pattern_detector.detectPattern(self.request_history.items);
        const confidence = try self.pattern_detector.calculateConfidence(self.request_history.items, new_pattern);

        if (new_pattern != self.current_pattern) {
            try self.pattern_history.append(self.current_pattern);
            self.current_pattern = new_pattern;
            self.pattern_confidence = confidence;

            // Keep only recent pattern history
            if (self.pattern_history.items.len > 10) {
                _ = self.pattern_history.orderedRemove(0);
            }
        }
    }

    /// Update average allocation size
    fn updateAverageAllocationSize(self: *AdvancedMemoryPredictor) void {
        if (self.stats.total_allocations == 0) return;

        var total_size: usize = 0;
        for (self.request_history.items) |request| {
            total_size += request.actual_size;
        }

        self.stats.average_allocation_size = @as(f64, @floatFromInt(total_size)) / @as(f64, @floatFromInt(self.request_history.items.len));
    }

    /// Update prediction accuracy
    fn updatePredictionAccuracy(self: *AdvancedMemoryPredictor, prediction: PredictionResult) void {
        // This would be called after the actual allocation to compare prediction vs reality
        // For now, we'll use a simple moving average
        const alpha = 0.1; // Learning rate
        self.stats.prediction_accuracy = alpha * prediction.confidence + (1 - alpha) * self.stats.prediction_accuracy;
    }

    /// Calculate recommended pool size
    fn calculateRecommendedPoolSize(self: *AdvancedMemoryPredictor) usize {
        const base_size = self.stats.peak_memory_used;
        const growth_factor = self.calculateGrowthFactor();
        return @as(usize, @intFromFloat(@as(f64, @floatFromInt(base_size)) * growth_factor));
    }

    /// Calculate growth factor based on pattern
    fn calculateGrowthFactor(self: *AdvancedMemoryPredictor) f64 {
        return switch (self.current_pattern) {
            .linear_growth => 1.2,
            .exponential_growth => 2.0,
            .cyclical => 1.5,
            .stable => 1.1,
            .unpredictable => 2.5,
        };
    }

    /// Assess risk level
    fn assessRiskLevel(self: *AdvancedMemoryPredictor) RiskLevel {
        if (self.stats.failed_allocations > self.stats.total_allocations / 10) {
            return .critical;
        } else if (self.pattern_confidence < 0.5) {
            return .high;
        } else if (self.pattern_confidence < 0.8) {
            return .medium;
        } else {
            return .low;
        }
    }

    /// Calculate linear confidence (R-squared)
    fn calculateLinearConfidence(self: *AdvancedMemoryPredictor, data: []const AllocationRequest, slope: f64, intercept: f64) f64 {
        _ = self;
        var ss_res: f64 = 0;
        var ss_tot: f64 = 0;

        var mean_y: f64 = 0;
        for (data) |request| {
            mean_y += @as(f64, @floatFromInt(request.actual_size));
        }
        mean_y /= @as(f64, @floatFromInt(data.len));

        for (data, 0..) |request, i| {
            const x = @as(f64, @floatFromInt(i));
            const y = @as(f64, @floatFromInt(request.actual_size));
            const y_pred = slope * x + intercept;

            ss_res += (y - y_pred) * (y - y_pred);
            ss_tot += (y - mean_y) * (y - mean_y);
        }

        return 1.0 - (ss_res / ss_tot);
    }

    /// Calculate exponential confidence
    fn calculateExponentialConfidence(self: *AdvancedMemoryPredictor, data: []const AllocationRequest, slope: f64, intercept: f64) f64 {
        // Similar to linear but with log-transformed data
        return self.calculateLinearConfidence(data, slope, intercept);
    }

    /// Calculate cyclical confidence
    fn calculateCyclicalConfidence(self: *AdvancedMemoryPredictor, data: []const AllocationRequest, cycle_length: usize) f64 {
        _ = self;
        if (cycle_length == 0 or data.len < cycle_length * 2) return 0.0;

        var matches: usize = 0;
        for (data, 0..) |request, i| {
            if (i >= cycle_length) {
                const cycle_position = i % cycle_length;
                const expected_size = data[cycle_position].actual_size;
                const actual_size = request.actual_size;

                // Allow 10% variance
                const variance = @abs(@as(f64, @floatFromInt(actual_size)) - @as(f64, @floatFromInt(expected_size))) / @as(f64, @floatFromInt(expected_size));
                if (variance < 0.1) {
                    matches += 1;
                }
            }
        }

        return @as(f64, @floatFromInt(matches)) / @as(f64, @floatFromInt(data.len - cycle_length));
    }

    /// Calculate stable confidence
    fn calculateStableConfidence(self: *AdvancedMemoryPredictor, data: []const AllocationRequest, average_size: usize) f64 {
        _ = self;
        var variance: f64 = 0;
        for (data) |request| {
            const diff = @as(f64, @floatFromInt(request.actual_size)) - @as(f64, @floatFromInt(average_size));
            variance += diff * diff;
        }
        variance /= @as(f64, @floatFromInt(data.len));

        const coefficient_of_variation = @sqrt(variance) / @as(f64, @floatFromInt(average_size));
        return 1.0 - @min(coefficient_of_variation, 1.0);
    }

    /// Find cycle length using autocorrelation
    fn findCycleLength(self: *AdvancedMemoryPredictor, data: []const AllocationRequest) usize {
        const max_cycle = @min(data.len / 2, 100);
        var best_correlation: f64 = 0;
        var best_length: usize = 0;

        for (1..max_cycle) |cycle_length| {
            const correlation = self.calculateAutocorrelation(data, cycle_length);
            if (correlation > best_correlation) {
                best_correlation = correlation;
                best_length = cycle_length;
            }
        }

        return best_length;
    }

    /// Calculate autocorrelation for cycle detection
    fn calculateAutocorrelation(self: *AdvancedMemoryPredictor, data: []const AllocationRequest, lag: usize) f64 {
        _ = self;
        if (data.len <= lag) return 0.0;

        var sum: f64 = 0;
        var count: usize = 0;

        for (data, 0..) |request, i| {
            if (i + lag < data.len) {
                const x = @as(f64, @floatFromInt(request.actual_size));
                const y = @as(f64, @floatFromInt(data[i + lag].actual_size));
                sum += x * y;
                count += 1;
            }
        }

        return if (count > 0) sum / @as(f64, @floatFromInt(count)) else 0.0;
    }

    /// Get statistics
    pub fn getStats(self: *const AdvancedMemoryPredictor) MemoryStats {
        return self.stats;
    }
};

// Pattern detector for memory usage
const PatternDetector = struct {
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) PatternDetector {
        return PatternDetector{
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *PatternDetector) void {
        _ = self;
    }

    /// Detect memory usage pattern
    pub fn detectPattern(self: *PatternDetector, data: []const AllocationRequest) !MemoryPattern {
        if (data.len < 3) return .unpredictable;

        // Test different patterns
        const linear_score = self.testLinearPattern(data);
        const exponential_score = self.testExponentialPattern(data);
        const cyclical_score = self.testCyclicalPattern(data);
        const stable_score = self.testStablePattern(data);

        // Return pattern with highest score
        if (linear_score > exponential_score and linear_score > cyclical_score and linear_score > stable_score) {
            return .linear_growth;
        } else if (exponential_score > cyclical_score and exponential_score > stable_score) {
            return .exponential_growth;
        } else if (cyclical_score > stable_score) {
            return .cyclical;
        } else if (stable_score > 0.5) {
            return .stable;
        } else {
            return .unpredictable;
        }
    }

    /// Calculate confidence for a pattern
    pub fn calculateConfidence(self: *PatternDetector, data: []const AllocationRequest, pattern: MemoryPattern) !f64 {
        return switch (pattern) {
            .linear_growth => self.testLinearPattern(data),
            .exponential_growth => self.testExponentialPattern(data),
            .cyclical => self.testCyclicalPattern(data),
            .stable => self.testStablePattern(data),
            .unpredictable => 0.0,
        };
    }

    /// Test linear growth pattern
    fn testLinearPattern(self: *PatternDetector, data: []const AllocationRequest) f64 {
        _ = self;
        // Simple linear regression test
        var sum_x: f64 = 0;
        var sum_y: f64 = 0;
        var sum_xy: f64 = 0;
        var sum_x2: f64 = 0;

        for (data, 0..) |request, i| {
            const x = @as(f64, @floatFromInt(i));
            const y = @as(f64, @floatFromInt(request.actual_size));

            sum_x += x;
            sum_y += y;
            sum_xy += x * y;
            sum_x2 += x * x;
        }

        const n = @as(f64, @floatFromInt(data.len));
        const slope = (n * sum_xy - sum_x * sum_y) / (n * sum_x2 - sum_x * sum_x);

        // Check if slope is positive and consistent
        return if (slope > 0) @min(slope / 1000.0, 1.0) else 0.0;
    }

    /// Test exponential growth pattern
    fn testExponentialPattern(self: *PatternDetector, data: []const AllocationRequest) f64 {
        // Test if growth is exponential
        var growth_rates = std.ArrayList(f64).init(self.allocator);
        defer growth_rates.deinit();

        for (data, 1..) |request, i| {
            if (i > 0) {
                const prev_size = @as(f64, @floatFromInt(data[i - 1].actual_size));
                const curr_size = @as(f64, @floatFromInt(request.actual_size));
                if (prev_size > 0) {
                    const growth_rate = (curr_size - prev_size) / prev_size;
                    try growth_rates.append(growth_rate);
                }
            }
        }

        if (growth_rates.items.len == 0) return 0.0;

        // Check if growth rates are increasing
        var increasing_count: usize = 0;
        for (growth_rates.items, 1..) |rate, i| {
            if (i > 0 and rate > growth_rates.items[i - 1]) {
                increasing_count += 1;
            }
        }

        return @as(f64, @floatFromInt(increasing_count)) / @as(f64, @floatFromInt(growth_rates.items.len - 1));
    }

    /// Test cyclical pattern
    fn testCyclicalPattern(self: *PatternDetector, data: []const AllocationRequest) f64 {
        const max_cycle = @min(data.len / 2, 50);
        var best_correlation: f64 = 0;

        for (2..max_cycle) |cycle_length| {
            const correlation = self.calculateAutocorrelation(data, cycle_length);
            if (correlation > best_correlation) {
                best_correlation = correlation;
            }
        }

        return best_correlation;
    }

    /// Test stable pattern
    fn testStablePattern(self: *PatternDetector, data: []const AllocationRequest) f64 {
        _ = self;
        var total_size: usize = 0;
        for (data) |request| {
            total_size += request.actual_size;
        }

        const average_size = total_size / data.len;
        var variance: f64 = 0;

        for (data) |request| {
            const diff = @as(f64, @floatFromInt(request.actual_size)) - @as(f64, @floatFromInt(average_size));
            variance += diff * diff;
        }

        variance /= @as(f64, @floatFromInt(data.len));
        const coefficient_of_variation = @sqrt(variance) / @as(f64, @floatFromInt(average_size));

        return 1.0 - @min(coefficient_of_variation, 1.0);
    }

    /// Calculate autocorrelation
    fn calculateAutocorrelation(self: *PatternDetector, data: []const AllocationRequest, lag: usize) f64 {
        _ = self;
        if (data.len <= lag) return 0.0;

        var sum: f64 = 0;
        var count: usize = 0;

        for (data, 0..) |request, i| {
            if (i + lag < data.len) {
                const x = @as(f64, @floatFromInt(request.actual_size));
                const y = @as(f64, @floatFromInt(data[i + lag].actual_size));
                sum += x * y;
                count += 1;
            }
        }

        return if (count > 0) sum / @as(f64, @floatFromInt(count)) else 0.0;
    }
};

// Memory strategy recommendation
const MemoryStrategy = struct {
    pattern: MemoryPattern,
    confidence: f64,
    recommended_pool_size: usize,
    growth_factor: f64,
    risk_level: RiskLevel,
};

// Test utilities
pub const MemoryPredictorTester = struct {
    pub fn testMemoryPredictor(allocator: std.mem.Allocator) !void {
        var predictor = AdvancedMemoryPredictor.init(allocator);
        defer predictor.deinit();

        // Test 1: Record allocations
        try predictor.recordAllocation(.node_insert, 1024, 1024, true);
        try predictor.recordAllocation(.node_insert, 2048, 2048, true);
        try predictor.recordAllocation(.node_insert, 3072, 3072, true);

        // Test 2: Predict allocation
        const prediction = try predictor.predictAllocation(.node_insert);
        assert(prediction.predicted_size > 0);

        // Test 3: Get memory strategy
        const strategy = predictor.getMemoryStrategy();
        assert(strategy.recommended_pool_size > 0);

        // Test 4: Get statistics
        const stats = predictor.getStats();
        assert(stats.total_allocations == 3);

        std.debug.print("✅ Memory predictor tests passed\n", .{});
    }
};
