// NenDB Document Processing Framework
// Handles PDFs, Word docs, images, videos, and other file types for RAG

const std = @import("std");
const data_types = @import("../data_types/extensible_properties.zig");

pub const DocumentProcessor = struct {
    name: []const u8,
    supported_formats: [][]const u8,
    process: *const fn([]u8) error{ProcessingError}!ProcessedDocument,
    
    pub fn init(name: []const u8, formats: [][]const u8, process_fn: *const fn([]u8) error{ProcessingError}!ProcessedDocument) DocumentProcessor {
        return DocumentProcessor{
            .name = name,
            .supported_formats = formats,
            .process = process_fn,
        };
    }
};

pub const ProcessedDocument = struct {
    metadata: data_types.DocumentMetadata,
    chunks: []data_types.DocumentChunk,
    embeddings: []data_types.MultiModalEmbedding,
    extracted_data: ExtractedData,
    
    pub fn deinit(self: *ProcessedDocument, allocator: std.mem.Allocator) void {
        self.metadata.deinit(allocator);
        for (self.chunks) |*chunk| chunk.deinit(allocator);
        allocator.free(self.chunks);
        for (self.embeddings) |*embedding| embedding.deinit(allocator);
        allocator.free(self.embeddings);
        self.extracted_data.deinit(allocator);
    }
};

pub const ExtractedData = union(enum) {
    text: TextData,
    image: ImageData,
    video: VideoData,
    audio: AudioData,
    pdf: PDFData,
    word: WordData,
    spreadsheet: SpreadsheetData,
    presentation: PresentationData,
    
    pub fn deinit(self: ExtractedData, allocator: std.mem.Allocator) void {
        switch (self) {
            .text => |t| t.deinit(allocator),
            .image => |i| i.deinit(allocator),
            .video => |v| v.deinit(allocator),
            .audio => |a| a.deinit(allocator),
            .pdf => |p| p.deinit(allocator),
            .word => |w| w.deinit(allocator),
            .spreadsheet => |s| s.deinit(allocator),
            .presentation => |p| p.deinit(allocator),
        }
    }
};

// Text data extraction
pub const TextData = struct {
    content: []const u8,
    language: data_types.Language,
    encoding: TextEncoding,
    entities: []data_types.Entity,
    
    pub fn deinit(self: TextData, allocator: std.mem.Allocator) void {
        allocator.free(self.content);
        for (self.entities) |entity| entity.deinit(allocator);
        allocator.free(self.entities);
    }
};

pub const TextEncoding = enum {
    utf8,
    utf16,
    ascii,
    iso8859_1,
    windows1252,
    unknown,
};

// Image data extraction
pub const ImageData = struct {
    format: ImageFormat,
    dimensions: ImageDimensions,
    color_space: ColorSpace,
    ocr_text: ?[]const u8,
    objects: []DetectedObject,
    faces: []DetectedFace,
    visual_features: VisualFeatures,
    
    pub fn deinit(self: ImageData, allocator: std.mem.Allocator) void {
        if (self.ocr_text) |text| allocator.free(text);
        for (self.objects) |obj| obj.deinit(allocator);
        allocator.free(self.objects);
        for (self.faces) |face| face.deinit(allocator);
        allocator.free(self.faces);
        self.visual_features.deinit(allocator);
    }
};

pub const ImageFormat = enum {
    png, jpeg, gif, webp, bmp, tiff, svg, heic, raw
};

pub const ImageDimensions = struct {
    width: u32,
    height: u32,
    depth: u8, // bits per pixel
};

pub const ColorSpace = enum {
    rgb, rgba, grayscale, cmyk, lab, hsv, yuv
};

pub const DetectedObject = struct {
    label: []const u8,
    confidence: f32,
    bounding_box: BoundingBox,
    embedding: [256]f32,
    
    pub fn deinit(self: DetectedObject, allocator: std.mem.Allocator) void {
        allocator.free(self.label);
    }
};

pub const DetectedFace = struct {
    bounding_box: BoundingBox,
    landmarks: []FaceLandmark,
    age: ?u8,
    gender: ?Gender,
    emotion: ?Emotion,
    confidence: f32,
    
    pub fn deinit(self: DetectedFace, allocator: std.mem.Allocator) void {
        allocator.free(self.landmarks);
    }
};

pub const BoundingBox = struct {
    x: f32,
    y: f32,
    width: f32,
    height: f32,
};

pub const FaceLandmark = struct {
    x: f32,
    y: f32,
    type: LandmarkType,
};

pub const LandmarkType = enum {
    left_eye, right_eye, nose, left_mouth, right_mouth
};

pub const Gender = enum { male, female, unknown };
pub const Emotion = enum { happy, sad, angry, surprised, neutral };

pub const VisualFeatures = struct {
    color_histogram: [256]f32,
    texture_features: [128]f32,
    shape_features: [64]f32,
    
    pub fn deinit(self: VisualFeatures, allocator: std.mem.Allocator) void {
        _ = self;
        _ = allocator;
        // No dynamic memory
    }
};

// Video data extraction
pub const VideoData = struct {
    format: VideoFormat,
    duration: f64,
    resolution: VideoResolution,
    frame_rate: f32,
    frames: []VideoFrame,
    audio_track: ?AudioTrack,
    subtitles: []Subtitle,
    transcript: ?[]const u8,
    
    pub fn deinit(self: VideoData, allocator: std.mem.Allocator) void {
        for (self.frames) |frame| frame.deinit(allocator);
        allocator.free(self.frames);
        if (self.audio_track) |audio| audio.deinit(allocator);
        for (self.subtitles) |sub| sub.deinit(allocator);
        allocator.free(self.subtitles);
        if (self.transcript) |trans| allocator.free(trans);
    }
};

pub const VideoFormat = enum {
    mp4, avi, mov, mkv, wmv, flv, webm, m4v
};

pub const VideoResolution = struct {
    width: u32,
    height: u32,
};

pub const VideoFrame = struct {
    timestamp: f64,
    frame_number: u32,
    objects: []DetectedObject,
    faces: []DetectedFace,
    embedding: [256]f32,
    
    pub fn deinit(self: VideoFrame, allocator: std.mem.Allocator) void {
        for (self.objects) |obj| obj.deinit(allocator);
        allocator.free(self.objects);
        for (self.faces) |face| face.deinit(allocator);
        allocator.free(self.faces);
    }
};

pub const AudioTrack = struct {
    format: AudioFormat,
    sample_rate: u32,
    channels: u8,
    duration: f64,
    transcript: ?[]const u8,
    speaker_segments: []SpeakerSegment,
    
    pub fn deinit(self: AudioTrack, allocator: std.mem.Allocator) void {
        if (self.transcript) |trans| allocator.free(trans);
        for (self.speaker_segments) |seg| seg.deinit(allocator);
        allocator.free(self.speaker_segments);
    }
};

pub const AudioFormat = enum {
    mp3, wav, flac, aac, ogg, m4a, wma
};

pub const SpeakerSegment = struct {
    speaker_id: []const u8,
    start_time: f64,
    end_time: f64,
    text: []const u8,
    confidence: f32,
    
    pub fn deinit(self: SpeakerSegment, allocator: std.mem.Allocator) void {
        allocator.free(self.speaker_id);
        allocator.free(self.text);
    }
};

pub const Subtitle = struct {
    start_time: f64,
    end_time: f64,
    text: []const u8,
    language: data_types.Language,
    
    pub fn deinit(self: Subtitle, allocator: std.mem.Allocator) void {
        allocator.free(self.text);
    }
};

// Audio data extraction
pub const AudioData = struct {
    format: AudioFormat,
    duration: f64,
    sample_rate: u32,
    channels: u8,
    transcript: ?[]const u8,
    speaker_segments: []SpeakerSegment,
    music_info: ?MusicInfo,
    
    pub fn deinit(self: AudioData, allocator: std.mem.Allocator) void {
        if (self.transcript) |trans| allocator.free(trans);
        for (self.speaker_segments) |seg| seg.deinit(allocator);
        allocator.free(self.speaker_segments);
        if (self.music_info) |music| music.deinit(allocator);
    }
};

pub const MusicInfo = struct {
    title: ?[]const u8,
    artist: ?[]const u8,
    album: ?[]const u8,
    genre: ?[]const u8,
    duration: f64,
    
    pub fn deinit(self: MusicInfo, allocator: std.mem.Allocator) void {
        if (self.title) |t| allocator.free(t);
        if (self.artist) |a| allocator.free(a);
        if (self.album) |al| allocator.free(al);
        if (self.genre) |g| allocator.free(g);
    }
};

// PDF data extraction
pub const PDFData = struct {
    page_count: u32,
    pages: []PDFPage,
    tables: []PDFTable,
    images: []PDFImage,
    bookmarks: []PDFBookmark,
    
    pub fn deinit(self: PDFData, allocator: std.mem.Allocator) void {
        for (self.pages) |page| page.deinit(allocator);
        allocator.free(self.pages);
        for (self.tables) |table| table.deinit(allocator);
        allocator.free(self.tables);
        for (self.images) |img| img.deinit(allocator);
        allocator.free(self.images);
        for (self.bookmarks) |bookmark| bookmark.deinit(allocator);
        allocator.free(self.bookmarks);
    }
};

pub const PDFPage = struct {
    page_number: u32,
    text_content: []const u8,
    images: []PDFImage,
    tables: []PDFTable,
    layout_info: PageLayout,
    
    pub fn deinit(self: PDFPage, allocator: std.mem.Allocator) void {
        allocator.free(self.text_content);
        for (self.images) |img| img.deinit(allocator);
        allocator.free(self.images);
        for (self.tables) |table| table.deinit(allocator);
        allocator.free(self.tables);
        self.layout_info.deinit(allocator);
    }
};

pub const PDFTable = struct {
    page_number: u32,
    rows: [][]const u8,
    headers: ?[]const u8,
    bounding_box: BoundingBox,
    
    pub fn deinit(self: PDFTable, allocator: std.mem.Allocator) void {
        for (self.rows) |row| {
            for (row) |cell| allocator.free(cell);
            allocator.free(row);
        }
        allocator.free(self.rows);
        if (self.headers) |headers| {
            for (headers) |header| allocator.free(header);
            allocator.free(headers);
        }
    }
};

pub const PDFImage = struct {
    page_number: u32,
    bounding_box: BoundingBox,
    image_data: []u8,
    format: ImageFormat,
    
    pub fn deinit(self: PDFImage, allocator: std.mem.Allocator) void {
        allocator.free(self.image_data);
    }
};

pub const PDFBookmark = struct {
    title: []const u8,
    page_number: u32,
    level: u8,
    
    pub fn deinit(self: PDFBookmark, allocator: std.mem.Allocator) void {
        allocator.free(self.title);
    }
};

pub const PageLayout = struct {
    margins: Margins,
    columns: u8,
    orientation: Orientation,
    
    pub fn deinit(self: PageLayout, allocator: std.mem.Allocator) void {
        _ = self;
        _ = allocator;
        // No dynamic memory
    }
};

pub const Margins = struct {
    top: f32,
    bottom: f32,
    left: f32,
    right: f32,
};

pub const Orientation = enum { portrait, landscape };

// Word document extraction
pub const WordData = struct {
    paragraphs: []Paragraph,
    tables: []WordTable,
    images: []WordImage,
    headers: []Header,
    footers: []Footer,
    styles: []Style,
    track_changes: []Revision,
    
    pub fn deinit(self: WordData, allocator: std.mem.Allocator) void {
        for (self.paragraphs) |para| para.deinit(allocator);
        allocator.free(self.paragraphs);
        for (self.tables) |table| table.deinit(allocator);
        allocator.free(self.tables);
        for (self.images) |img| img.deinit(allocator);
        allocator.free(self.images);
        for (self.headers) |header| header.deinit(allocator);
        allocator.free(self.headers);
        for (self.footers) |footer| footer.deinit(allocator);
        allocator.free(self.footers);
        for (self.styles) |style| style.deinit(allocator);
        allocator.free(self.styles);
        for (self.track_changes) |revision| revision.deinit(allocator);
        allocator.free(self.track_changes);
    }
};

pub const Paragraph = struct {
    text: []const u8,
    style: ?[]const u8,
    alignment: Alignment,
    font_size: ?u16,
    font_name: ?[]const u8,
    
    pub fn deinit(self: Paragraph, allocator: std.mem.Allocator) void {
        allocator.free(self.text);
        if (self.style) |s| allocator.free(s);
        if (self.font_name) |f| allocator.free(f);
    }
};

pub const WordTable = struct {
    rows: [][]const u8,
    headers: ?[]const u8,
    style: ?[]const u8,
    
    pub fn deinit(self: WordTable, allocator: std.mem.Allocator) void {
        for (self.rows) |row| {
            for (row) |cell| allocator.free(cell);
            allocator.free(row);
        }
        allocator.free(self.rows);
        if (self.headers) |headers| {
            for (headers) |header| allocator.free(header);
            allocator.free(headers);
        }
        if (self.style) |s| allocator.free(s);
    }
};

pub const WordImage = struct {
    image_data: []u8,
    format: ImageFormat,
    caption: ?[]const u8,
    
    pub fn deinit(self: WordImage, allocator: std.mem.Allocator) void {
        allocator.free(self.image_data);
        if (self.caption) |c| allocator.free(c);
    }
};

pub const Header = struct {
    text: []const u8,
    page_number: ?u32,
    
    pub fn deinit(self: Header, allocator: std.mem.Allocator) void {
        allocator.free(self.text);
    }
};

pub const Footer = struct {
    text: []const u8,
    page_number: ?u32,
    
    pub fn deinit(self: Footer, allocator: std.mem.Allocator) void {
        allocator.free(self.text);
    }
};

pub const Style = struct {
    name: []const u8,
    font_name: ?[]const u8,
    font_size: ?u16,
    bold: bool,
    italic: bool,
    underline: bool,
    
    pub fn deinit(self: Style, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        if (self.font_name) |f| allocator.free(f);
    }
};

pub const Revision = struct {
    author: []const u8,
    timestamp: data_types.Timestamp,
    change_type: ChangeType,
    old_text: ?[]const u8,
    new_text: ?[]const u8,
    
    pub fn deinit(self: Revision, allocator: std.mem.Allocator) void {
        allocator.free(self.author);
        if (self.old_text) |t| allocator.free(t);
        if (self.new_text) |t| allocator.free(t);
    }
};

pub const ChangeType = enum {
    insertion,
    deletion,
    replacement,
    formatting,
};

pub const Alignment = enum {
    left, center, right, justify
};

// Spreadsheet data extraction
pub const SpreadsheetData = struct {
    sheets: []Sheet,
    formulas: []Formula,
    charts: []Chart,
    
    pub fn deinit(self: SpreadsheetData, allocator: std.mem.Allocator) void {
        for (self.sheets) |sheet| sheet.deinit(allocator);
        allocator.free(self.sheets);
        for (self.formulas) |formula| formula.deinit(allocator);
        allocator.free(self.formulas);
        for (self.charts) |chart| chart.deinit(allocator);
        allocator.free(self.charts);
    }
};

pub const Sheet = struct {
    name: []const u8,
    cells: [][]Cell,
    
    pub fn deinit(self: Sheet, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        for (self.cells) |row| {
            for (row) |cell| cell.deinit(allocator);
            allocator.free(row);
        }
        allocator.free(self.cells);
    }
};

pub const Cell = struct {
    value: []const u8,
    formula: ?[]const u8,
    format: ?[]const u8,
    
    pub fn deinit(self: Cell, allocator: std.mem.Allocator) void {
        allocator.free(self.value);
        if (self.formula) |f| allocator.free(f);
        if (self.format) |f| allocator.free(f);
    }
};

pub const Formula = struct {
    cell_ref: []const u8,
    formula_text: []const u8,
    result: ?[]const u8,
    
    pub fn deinit(self: Formula, allocator: std.mem.Allocator) void {
        allocator.free(self.cell_ref);
        allocator.free(self.formula_text);
        if (self.result) |r| allocator.free(r);
    }
};

pub const Chart = struct {
    title: []const u8,
    chart_type: ChartType,
    data_range: []const u8,
    
    pub fn deinit(self: Chart, allocator: std.mem.Allocator) void {
        allocator.free(self.title);
        allocator.free(self.data_range);
    }
};

pub const ChartType = enum {
    line, bar, pie, scatter, area, column
};

// Presentation data extraction
pub const PresentationData = struct {
    slides: []Slide,
    notes: []SlideNote,
    master_slides: []MasterSlide,
    
    pub fn deinit(self: PresentationData, allocator: std.mem.Allocator) void {
        for (self.slides) |slide| slide.deinit(allocator);
        allocator.free(self.slides);
        for (self.notes) |note| note.deinit(allocator);
        allocator.free(self.notes);
        for (self.master_slides) |master| master.deinit(allocator);
        allocator.free(self.master_slides);
    }
};

pub const Slide = struct {
    slide_number: u32,
    title: ?[]const u8,
    content: []SlideElement,
    background: ?[]const u8,
    
    pub fn deinit(self: Slide, allocator: std.mem.Allocator) void {
        if (self.title) |t| allocator.free(t);
        for (self.content) |element| element.deinit(allocator);
        allocator.free(self.content);
        if (self.background) |b| allocator.free(b);
    }
};

pub const SlideElement = union(enum) {
    text: []const u8,
    image: []const u8,
    shape: Shape,
    
    pub fn deinit(self: SlideElement, allocator: std.mem.Allocator) void {
        switch (self) {
            .text => |t| allocator.free(t),
            .image => |i| allocator.free(i),
            .shape => |s| s.deinit(allocator),
        }
    }
};

pub const Shape = struct {
    shape_type: ShapeType,
    text: ?[]const u8,
    position: Position,
    
    pub fn deinit(self: Shape, allocator: std.mem.Allocator) void {
        if (self.text) |t| allocator.free(t);
    }
};

pub const ShapeType = enum {
    rectangle, circle, triangle, arrow, line
};

pub const Position = struct {
    x: f32,
    y: f32,
    width: f32,
    height: f32,
};

pub const SlideNote = struct {
    slide_number: u32,
    notes: []const u8,
    
    pub fn deinit(self: SlideNote, allocator: std.mem.Allocator) void {
        allocator.free(self.notes);
    }
};

pub const MasterSlide = struct {
    name: []const u8,
    elements: []SlideElement,
    
    pub fn deinit(self: MasterSlide, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        for (self.elements) |element| element.deinit(allocator);
        allocator.free(self.elements);
    }
};

// Processing errors
pub const ProcessingError = error{
    UnsupportedFormat,
    CorruptedFile,
    ExtractionFailed,
    OutOfMemory,
    InvalidData,
    ProcessingTimeout,
};

// Document processor registry
pub const ProcessorRegistry = struct {
    processors: std.StringHashMap(DocumentProcessor),
    
    pub fn init(allocator: std.mem.Allocator) ProcessorRegistry {
        return ProcessorRegistry{ .processors = std.StringHashMap(DocumentProcessor).init(allocator) };
    }
    
    pub fn deinit(self: *ProcessorRegistry) void {
        self.processors.deinit();
    }
    
    pub fn register(self: *ProcessorRegistry, processor: DocumentProcessor) !void {
        const name_copy = try self.processors.allocator.dupe(u8, processor.name);
        try self.processors.put(name_copy, processor);
    }
    
    pub fn getProcessor(self: *const ProcessorRegistry, format: []const u8) ?DocumentProcessor {
        var it = self.processors.iterator();
        while (it.next()) |entry| {
            const processor = entry.value_ptr;
            for (processor.supported_formats) |supported_format| {
                if (std.mem.eql(u8, format, supported_format)) {
                    return processor.*;
                }
            }
        }
        return null;
    }
    
    pub fn listSupportedFormats(self: *const ProcessorRegistry) [][]const u8 {
        var formats = std.ArrayList([]const u8).init(self.processors.allocator);
        var it = self.processors.iterator();
        while (it.next()) |entry| {
            const processor = entry.value_ptr;
            for (processor.supported_formats) |format| {
                formats.append(format) catch continue;
            }
        }
        return formats.toOwnedSlice() catch &[_][]const u8{};
    }
};
