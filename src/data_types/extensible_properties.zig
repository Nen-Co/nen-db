// NenDB Extensible Property System
// Replaces fixed-size binary blobs with proper data type support

const std = @import("std");

// Core property value types
pub const PropertyValue = union(enum) {
    null: void,
    boolean: bool,
    integer: i64,
    float: f64,
    string: []const u8,
    binary: []u8,
    timestamp: Timestamp,
    json: JSONValue,
    vector: [256]f32,
    geo_point: GeoPoint,
    time_series: TimeSeries,
    
    // RAG-specific types
    document_chunk: DocumentChunk,
    multi_modal_embedding: MultiModalEmbedding,
    document_metadata: DocumentMetadata,
    
    pub fn deinit(self: PropertyValue, allocator: std.mem.Allocator) void {
        switch (self) {
            .string => |s| allocator.free(s),
            .binary => |b| allocator.free(b),
            .json => |j| deinitJSON(j, allocator),
            .time_series => |ts| deinitTimeSeries(ts, allocator),
            .document_chunk => |dc| deinitDocumentChunk(dc, allocator),
            .multi_modal_embedding => |mme| deinitMultiModalEmbedding(mme, allocator),
            .document_metadata => |dm| deinitDocumentMetadata(dm, allocator),
            else => {},
        }
    }
    
    pub fn getTypeName(self: PropertyValue) []const u8 {
        return switch (self) {
            .null => "null",
            .boolean => "boolean",
            .integer => "integer",
            .float => "float",
            .string => "string",
            .binary => "binary",
            .timestamp => "timestamp",
            .json => "json",
            .vector => "vector",
            .geo_point => "geo_point",
            .time_series => "time_series",
            .document_chunk => "document_chunk",
            .multi_modal_embedding => "multi_modal_embedding",
            .document_metadata => "document_metadata",
        };
    }
};

// Timestamp with nanosecond precision
pub const Timestamp = struct {
    seconds: i64,               // Unix timestamp
    nanoseconds: u32,           // Sub-second precision
    
    pub fn now() Timestamp {
        const now_ns = std.time.nanoTimestamp();
        return Timestamp{
            .seconds = @divFloor(now_ns, 1_000_000_000),
            .nanoseconds = @intCast(@mod(now_ns, 1_000_000_000)),
        };
    }
    
    pub fn fromUnix(seconds: i64) Timestamp {
        return Timestamp{ .seconds = seconds, .nanoseconds = 0 };
    }
    
    pub fn toUnix(self: Timestamp) i64 {
        return self.seconds;
    }
    
    pub fn toUnixNanos(self: Timestamp) i64 {
        return self.seconds * 1_000_000_000 + self.nanoseconds;
    }
};

// JSON value support
pub const JSONValue = union(enum) {
    null: void,
    boolean: bool,
    number: f64,
    string: []const u8,
    array: []JSONValue,
    object: std.StringHashMap(JSONValue),
    
    pub fn deinit(self: JSONValue, allocator: std.mem.Allocator) void {
        switch (self) {
            .string => |s| allocator.free(s),
            .array => |arr| {
                for (arr) |item| item.deinit(allocator);
                allocator.free(arr);
            },
            .object => |obj| {
                var it = obj.iterator();
                while (it.next()) |entry| {
                    allocator.free(entry.key_ptr.*);
                    entry.value_ptr.deinit(allocator);
                }
                obj.deinit();
            },
            else => {},
        }
    }
};

// Geographic point
pub const GeoPoint = struct {
    latitude: f64,
    longitude: f64,
    altitude: ?f64,
    
    pub fn init(lat: f64, lon: f64) GeoPoint {
        return GeoPoint{ .latitude = lat, .longitude = lon, .altitude = null };
    }
    
    pub fn init3D(lat: f64, lon: f64, alt: f64) GeoPoint {
        return GeoPoint{ .latitude = lat, .longitude = lon, .altitude = alt };
    }
    
    pub fn distance(self: GeoPoint, other: GeoPoint) f64 {
        // Haversine formula for great circle distance
        const lat1_rad = self.latitude * std.math.pi / 180.0;
        const lat2_rad = other.latitude * std.math.pi / 180.0;
        const delta_lat = (other.latitude - self.latitude) * std.math.pi / 180.0;
        const delta_lon = (other.longitude - self.longitude) * std.math.pi / 180.0;
        
        const a = std.math.sin(delta_lat / 2) * std.math.sin(delta_lat / 2) +
                  std.math.cos(lat1_rad) * std.math.cos(lat2_rad) *
                  std.math.sin(delta_lon / 2) * std.math.sin(delta_lon / 2);
        const c = 2 * std.math.atan2(std.math.sqrt(a), std.math.sqrt(1 - a));
        
        return 6371000 * c; // Earth radius in meters
    }
};

// Time series data
pub const TimeSeries = struct {
    start_time: Timestamp,
    end_time: Timestamp,
    data_points: []DataPoint,
    resolution: TimeResolution,
    
    pub fn deinit(self: TimeSeries, allocator: std.mem.Allocator) void {
        for (self.data_points) |point| {
            if (point.metadata) |meta| allocator.free(meta);
        }
        allocator.free(self.data_points);
    }
};

pub const DataPoint = struct {
    timestamp: Timestamp,
    value: f64,
    metadata: ?[]const u8,
};

pub const TimeResolution = enum {
    millisecond,
    second,
    minute,
    hour,
    day,
    week,
    month,
    year,
};

// RAG-specific data types

// Document chunk for text processing
pub const DocumentChunk = struct {
    // Content
    text: []const u8,
    chunk_type: ChunkType,
    
    // Source tracking
    source_document: u64,       // Node ID
    page_number: ?u32,
    section: ?[]const u8,
    
    // Position information
    char_start: u32,
    char_end: u32,
    line_start: u32,
    line_end: u32,
    
    // RAG metadata
    embedding: [256]f32,
    keywords: [][]const u8,
    entities: []Entity,
    
    // Quality metrics
    relevance_score: f32,
    readability_score: f32,
    confidence: f32,
    
    pub fn deinit(self: DocumentChunk, allocator: std.mem.Allocator) void {
        allocator.free(self.text);
        if (self.section) |s| allocator.free(s);
        for (self.keywords) |keyword| allocator.free(keyword);
        allocator.free(self.keywords);
        for (self.entities) |entity| deinitEntity(entity, allocator);
        allocator.free(self.entities);
    }
};

pub const ChunkType = enum {
    paragraph,
    sentence,
    table,
    image_caption,
    code_block,
    header,
    list_item,
};

pub const Entity = struct {
    text: []const u8,
    type: EntityType,
    confidence: f32,
    start_pos: u32,
    end_pos: u32,
    
    pub fn deinit(self: Entity, allocator: std.mem.Allocator) void {
        allocator.free(self.text);
    }
};

pub const EntityType = enum {
    person,
    organization,
    location,
    date,
    money,
    percentage,
    url,
    email,
    phone,
    custom,
};

// Multi-modal embeddings for AI/ML
pub const MultiModalEmbedding = struct {
    // Text embedding
    text_embedding: [256]f32,
    
    // Visual embedding (for images/videos)
    visual_embedding: ?[256]f32,
    
    // Audio embedding (for audio/video)
    audio_embedding: ?[256]f32,
    
    // Combined embedding
    combined_embedding: [256]f32,
    
    // Modality weights
    text_weight: f32,
    visual_weight: f32,
    audio_weight: f32,
    
    pub fn deinit(self: MultiModalEmbedding, allocator: std.mem.Allocator) void {
        _ = self;
        _ = allocator;
        // No dynamic memory to free
    }
    
    pub fn combineEmbeddings(self: *MultiModalEmbedding) void {
        for (0..256) |i| {
            var combined: f32 = self.text_embedding[i] * self.text_weight;
            if (self.visual_embedding) |ve| {
                combined += ve[i] * self.visual_weight;
            }
            if (self.audio_embedding) |ae| {
                combined += ae[i] * self.audio_weight;
            }
            self.combined_embedding[i] = combined;
        }
    }
};

// Document metadata for RAG
pub const DocumentMetadata = struct {
    // Basic info
    title: []const u8,
    author: []const u8,
    creation_date: Timestamp,
    modification_date: Timestamp,
    
    // File info
    filename: []const u8,
    file_size: u64,
    mime_type: []const u8,
    checksum: [32]u8,
    
    // Content info
    language: Language,
    page_count: ?u32,
    word_count: ?u32,
    
    // RAG info
    chunk_count: u32,
    average_chunk_size: u32,
    processing_status: ProcessingStatus,
    
    // Custom metadata
    tags: [][]const u8,
    categories: [][]const u8,
    custom_fields: std.StringHashMap([]const u8),
    
    pub fn deinit(self: DocumentMetadata, allocator: std.mem.Allocator) void {
        allocator.free(self.title);
        allocator.free(self.author);
        allocator.free(self.filename);
        allocator.free(self.mime_type);
        for (self.tags) |tag| allocator.free(tag);
        allocator.free(self.tags);
        for (self.categories) |cat| allocator.free(cat);
        allocator.free(self.categories);
        var it = self.custom_fields.iterator();
        while (it.next()) |entry| {
            allocator.free(entry.key_ptr.*);
            allocator.free(entry.value_ptr.*);
        }
        self.custom_fields.deinit();
    }
};

pub const Language = enum {
    english,
    spanish,
    french,
    german,
    chinese,
    japanese,
    korean,
    russian,
    arabic,
    hindi,
    portuguese,
    italian,
    dutch,
    swedish,
    norwegian,
    danish,
    finnish,
    polish,
    turkish,
    greek,
    hebrew,
    thai,
    vietnamese,
    indonesian,
    malay,
    filipino,
    urdu,
    persian,
    bengali,
    tamil,
    telugu,
    marathi,
    gujarati,
    kannada,
    malayalam,
    punjabi,
    odia,
    assamese,
    nepali,
    sinhala,
    burmese,
    khmer,
    lao,
    mongolian,
    tibetan,
    uyghur,
    kazakh,
    kyrgyz,
    tajik,
    turkmen,
    azerbaijani,
    georgian,
    armenian,
    unknown,
};

pub const ProcessingStatus = enum {
    pending,
    processing,
    completed,
    failed,
    partial,
};

// Extensible property map
pub const PropertyMap = struct {
    map: std.StringHashMap(PropertyValue),
    
    pub fn init(allocator: std.mem.Allocator) PropertyMap {
        return PropertyMap{ .map = std.StringHashMap(PropertyValue).init(allocator) };
    }
    
    pub fn deinit(self: *PropertyMap) void {
        var it = self.map.iterator();
        while (it.next()) |entry| {
            self.map.allocator.free(entry.key_ptr.*);
            entry.value_ptr.deinit(self.map.allocator);
        }
        self.map.deinit();
    }
    
    pub fn put(self: *PropertyMap, key: []const u8, value: PropertyValue) !void {
        const key_copy = try self.map.allocator.dupe(u8, key);
        try self.map.put(key_copy, value);
    }
    
    pub fn get(self: *const PropertyMap, key: []const u8) ?PropertyValue {
        return self.map.get(key);
    }
    
    pub fn remove(self: *PropertyMap, key: []const u8) ?PropertyValue {
        if (self.map.fetchRemove(key)) |entry| {
            self.map.allocator.free(entry.key);
            entry.value.deinit(self.map.allocator);
            return entry.value;
        }
        return null;
    }
    
    pub fn contains(self: *const PropertyMap, key: []const u8) bool {
        return self.map.contains(key);
    }
    
    pub fn count(self: *const PropertyMap) usize {
        return self.map.count();
    }
};

// Helper functions
fn deinitJSON(json: JSONValue, allocator: std.mem.Allocator) void {
    json.deinit(allocator);
}

fn deinitTimeSeries(ts: TimeSeries, allocator: std.mem.Allocator) void {
    ts.deinit(allocator);
}

fn deinitDocumentChunk(dc: DocumentChunk, allocator: std.mem.Allocator) void {
    dc.deinit(allocator);
}

fn deinitMultiModalEmbedding(mme: MultiModalEmbedding, allocator: std.mem.Allocator) void {
    mme.deinit(allocator);
}

fn deinitDocumentMetadata(dm: DocumentMetadata, allocator: std.mem.Allocator) void {
    dm.deinit(allocator);
}

fn deinitEntity(entity: Entity, allocator: std.mem.Allocator) void {
    entity.deinit(allocator);
}
