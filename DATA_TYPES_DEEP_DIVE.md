# NenDB Data Types Deep Dive: Current vs Needed for RAG

## Executive Summary

**Current State**: Basic graph + vector support
**RAG Requirements**: Comprehensive document/media support with rich metadata
**Gap**: Missing temporal, spatial, binary, and rich text capabilities

## Current Data Types Analysis

### ✅ What We Have

#### 1. Core Graph Structure
```zig
// Nodes: 128 bytes for properties
pub const Node = extern struct {
    id: u64,                    // 64-bit unique ID
    kind: u8,                   // 256 node types
    props: [128]u8,             // Binary blob
};

// Edges: 64 bytes for properties  
pub const Edge = extern struct {
    from: u64, to: u64,         // Node references
    label: u16,                 // 65K relationship types
    props: [64]u8,              // Binary blob
};
```

#### 2. Vector Support
```zig
// 256-dimensional embeddings
pub const Embedding = extern struct {
    node_id: u64,
    vector: [256]f32,           // 1KB per embedding
};
```

#### 3. Cypher Data Types
- **Primitives**: `string`, `integer`, `float`, `boolean`, `null`
- **Collections**: `map`, `list`
- **Variables**: Node/edge references

### ❌ What We're Missing for RAG

## RAG Document Types Deep Dive

### 1. PDF Documents

#### Current Limitations
- **No native PDF parsing**
- **No text extraction**
- **No page-level granularity**
- **No metadata extraction**

#### RAG Requirements
```zig
// PDF Document Structure
pub const PDFDocument = struct {
    // Core metadata
    title: []const u8,
    author: []const u8,
    creation_date: Timestamp,
    page_count: u32,
    file_size: u64,
    
    // Content structure
    pages: []PDFPage,
    sections: []PDFSection,
    
    // Extracted content
    text_content: []const u8,
    tables: []PDFTable,
    images: []PDFImage,
    
    // RAG-specific
    chunks: []TextChunk,
    embeddings: []DocumentEmbedding,
};

pub const PDFPage = struct {
    page_number: u32,
    text_content: []const u8,
    images: []PDFImage,
    tables: []PDFTable,
    layout_info: PageLayout,
};

pub const TextChunk = struct {
    content: []const u8,
    page_start: u32,
    page_end: u32,
    char_start: u32,
    char_end: u32,
    embedding: [256]f32,
    metadata: ChunkMetadata,
};
```

### 2. Word Documents (.docx)

#### Current Limitations
- **No Office document parsing**
- **No formatting preservation**
- **No revision tracking**

#### RAG Requirements
```zig
pub const WordDocument = struct {
    // Core metadata
    title: []const u8,
    author: []const u8,
    last_modified: Timestamp,
    revision_count: u32,
    
    // Content structure
    paragraphs: []Paragraph,
    tables: []WordTable,
    images: []WordImage,
    headers: []Header,
    footers: []Footer,
    
    // Formatting
    styles: []Style,
    formatting: []Formatting,
    
    // RAG-specific
    chunks: []TextChunk,
    track_changes: []Revision,
};
```

### 3. Images (PNG, JPEG, GIF, WebP, etc.)

#### Current Limitations
- **No image processing**
- **No OCR capabilities**
- **No visual similarity search**

#### RAG Requirements
```zig
pub const ImageDocument = struct {
    // Core metadata
    filename: []const u8,
    format: ImageFormat,
    dimensions: ImageDimensions,
    file_size: u64,
    
    // Image data
    pixels: []u8,               // Raw pixel data
    thumbnail: []u8,            // Compressed thumbnail
    
    // Extracted content
    ocr_text: []const u8,       // Text from OCR
    objects: []DetectedObject,  // Object detection
    faces: []DetectedFace,      // Face detection
    
    // Visual embeddings
    visual_embedding: [256]f32, // Image similarity
    feature_vector: [512]f32,   // Deep features
};

pub const ImageFormat = enum {
    png, jpeg, gif, webp, bmp, tiff, svg, heic
};

pub const DetectedObject = struct {
    label: []const u8,
    confidence: f32,
    bounding_box: BoundingBox,
    embedding: [256]f32,
};
```

### 4. Videos (MP4, AVI, MOV, etc.)

#### Current Limitations
- **No video processing**
- **No frame extraction**
- **No audio transcription**

#### RAG Requirements
```zig
pub const VideoDocument = struct {
    // Core metadata
    filename: []const u8,
    format: VideoFormat,
    duration: f64,              // seconds
    resolution: VideoResolution,
    file_size: u64,
    
    // Video content
    frames: []VideoFrame,       // Key frames
    audio_track: AudioTrack,
    subtitles: []Subtitle,
    
    // Extracted content
    transcript: []const u8,     // Audio transcription
    scene_changes: []SceneChange,
    objects: []VideoObject,     // Object tracking
    
    // Multi-modal embeddings
    visual_embeddings: []FrameEmbedding,
    audio_embedding: [256]f32,
    transcript_embedding: [256]f32,
};

pub const VideoFrame = struct {
    timestamp: f64,
    frame_number: u32,
    pixels: []u8,
    objects: []DetectedObject,
    embedding: [256]f32,
};

pub const AudioTrack = struct {
    format: AudioFormat,
    sample_rate: u32,
    channels: u8,
    duration: f64,
    audio_data: []u8,
};
```

### 5. Audio Files (MP3, WAV, FLAC, etc.)

#### Current Limitations
- **No audio processing**
- **No speech recognition**

#### RAG Requirements
```zig
pub const AudioDocument = struct {
    // Core metadata
    filename: []const u8,
    format: AudioFormat,
    duration: f64,
    sample_rate: u32,
    channels: u8,
    
    // Extracted content
    transcript: []const u8,
    speaker_segments: []SpeakerSegment,
    music_info: ?MusicInfo,
    
    // Audio embeddings
    audio_embedding: [256]f32,
    transcript_embedding: [256]f32,
};

pub const SpeakerSegment = struct {
    speaker_id: []const u8,
    start_time: f64,
    end_time: f64,
    text: []const u8,
    confidence: f32,
};
```

## Missing Data Types Analysis

### 1. Temporal Data (Critical for RAG)

#### Current Gap
- **No timestamp support**
- **No time-series data**
- **No temporal queries**

#### Required Implementation
```zig
pub const Timestamp = struct {
    seconds: i64,               // Unix timestamp
    nanoseconds: u32,           // Sub-second precision
};

pub const TimeSeries = struct {
    start_time: Timestamp,
    end_time: Timestamp,
    data_points: []DataPoint,
    resolution: TimeResolution,
};

pub const DataPoint = struct {
    timestamp: Timestamp,
    value: f64,
    metadata: ?[]const u8,
};
```

### 2. Spatial Data (Important for RAG)

#### Current Gap
- **No geographic coordinates**
- **No spatial indexing**
- **No location-based queries**

#### Required Implementation
```zig
pub const GeoPoint = struct {
    latitude: f64,
    longitude: f64,
    altitude: ?f64,
};

pub const GeoPolygon = struct {
    points: []GeoPoint,
    holes: [][]GeoPoint,
};

pub const SpatialIndex = struct {
    rtree: RTree,
    geohash: GeoHash,
};
```

### 3. Rich Text (Essential for RAG)

#### Current Gap
- **No full-text search**
- **No text indexing**
- **No semantic text analysis**

#### Required Implementation
```zig
pub const RichText = struct {
    content: []const u8,
    format: TextFormat,
    language: Language,
    tokens: []Token,
    entities: []Entity,
};

pub const TextIndex = struct {
    inverted_index: InvertedIndex,
    semantic_index: SemanticIndex,
    ngram_index: NGramIndex,
};

pub const Entity = struct {
    text: []const u8,
    type: EntityType,
    confidence: f32,
    start_pos: u32,
    end_pos: u32,
};
```

### 4. Binary Data (Critical for RAG)

#### Current Gap
- **No binary storage**
- **No file attachments**
- **No blob support**

#### Required Implementation
```zig
pub const BinaryData = struct {
    data: []u8,
    mime_type: []const u8,
    checksum: [32]u8,
    compression: CompressionType,
    encryption: ?EncryptionInfo,
};

pub const FileAttachment = struct {
    filename: []const u8,
    size: u64,
    binary_data: BinaryData,
    metadata: FileMetadata,
};
```

### 5. JSON Support (Important for RAG)

#### Current Gap
- **No native JSON**
- **No JSON querying**
- **No JSON validation**

#### Required Implementation
```zig
pub const JSONValue = union(enum) {
    null: void,
    boolean: bool,
    number: f64,
    string: []const u8,
    array: []JSONValue,
    object: std.StringHashMap(JSONValue),
};

pub const JSONDocument = struct {
    root: JSONValue,
    schema: ?JSONSchema,
    validation: ValidationResult,
};
```

## RAG-Specific Data Types

### 1. Document Chunks
```zig
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
```

### 2. Multi-Modal Embeddings
```zig
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
};
```

### 3. Document Metadata
```zig
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
};
```

## Implementation Priority for RAG

### Phase 1: Critical (Next 2-4 weeks)
1. **Binary Data Support**
   - File attachments
   - Blob storage
   - MIME type handling

2. **Temporal Data**
   - Timestamps
   - Time-series queries
   - Temporal indexing

3. **Rich Text**
   - Full-text search
   - Text indexing
   - Basic text analysis

### Phase 2: Important (Next 1-2 months)
1. **JSON Support**
   - Native JSON storage
   - JSON querying
   - Schema validation

2. **Document Processing**
   - PDF parsing
   - Word document parsing
   - Text extraction

3. **Image Support**
   - Image storage
   - Basic image processing
   - OCR integration

### Phase 3: Advanced (Next 3-6 months)
1. **Video/Audio Processing**
   - Video frame extraction
   - Audio transcription
   - Multi-modal embeddings

2. **Spatial Data**
   - Geographic coordinates
   - Spatial indexing
   - Location queries

3. **Advanced Analytics**
   - Document clustering
   - Content analysis
   - Quality scoring

## Technical Implementation Strategy

### 1. Extensible Property System
```zig
// Replace fixed-size props with extensible system
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
    // Extensible for future types
};

pub const PropertyMap = std.StringHashMap(PropertyValue);
```

### 2. Plugin Architecture
```zig
// Document processor plugins
pub const DocumentProcessor = struct {
    name: []const u8,
    supported_formats: [][]const u8,
    process: *const fn([]u8) error{ProcessingError}!ProcessedDocument,
};

pub const ProcessedDocument = struct {
    metadata: DocumentMetadata,
    chunks: []DocumentChunk,
    embeddings: []MultiModalEmbedding,
    extracted_data: ExtractedData,
};
```

### 3. Storage Optimization
```zig
// Tiered storage for different data types
pub const StorageTier = enum {
    memory,     // Hot data (embeddings, metadata)
    ssd,        // Warm data (text, small binaries)
    hdd,        // Cold data (large files, videos)
    cloud,      // Archive data (old documents)
};
```

## Conclusion

**Current State**: Basic graph + vector (good foundation)
**RAG Requirements**: Comprehensive multi-modal document support
**Gap**: Missing 70% of data types needed for production RAG

**Priority**: Focus on binary data, temporal data, and rich text first, as these are critical for any RAG system. Then add document processing capabilities for PDFs, Word docs, and images. Advanced features like video processing can come later.

This analysis shows we need significant data type expansion to be competitive in the RAG space, but our current foundation with compiled Cypher + vectors gives us a strong starting point.
