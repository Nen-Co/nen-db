const std = @import("std");
const print = std.debug.print;

// Forward declaration - Database type will be provided by the user
const Database = anyopaque;

/// Structure to represent a knowledge graph triple (Subject-Predicate-Object)
pub const KnowledgeTriple = struct {
    subject: []const u8,
    predicate: []const u8,
    object: []const u8,
};

/// CSV parser for knowledge graph data
pub const KnowledgeGraphParser = struct {
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .allocator = allocator,
        };
    }

    /// Parse CSV file with knowledge graph triples
    /// Expected formats:
    /// - subject,predicate,object
    /// - entity1,relationship,entity2
    /// - head,relation,tail
    pub fn parseCSV(self: *Self, file_path: []const u8) !std.array_list.Managed(KnowledgeTriple) {
        var file = std.fs.cwd().openFile(file_path, .{}) catch |err| {
            print("❌ Failed to open file '{s}': {}\n", .{ file_path, err });
            return err;
        };
        defer file.close();

        const file_size = try file.getEndPos();
        const contents = try self.allocator.alloc(u8, file_size);
        defer self.allocator.free(contents);
        _ = try file.readAll(contents);

        var triples = std.array_list.Managed(KnowledgeTriple).init(self.allocator);
        var lines = std.mem.splitSequence(u8, contents, "\n");

        var line_count: u32 = 0;
        var header_skipped = false;

        while (lines.next()) |line| {
            line_count += 1;

            // Skip empty lines
            if (std.mem.trim(u8, line, " \t\r\n").len == 0) continue;

            // Skip header if it contains common CSV headers
            if (!header_skipped) {
                const trimmed = std.mem.trim(u8, line, " \t\r\n");
                if (std.mem.indexOf(u8, trimmed, "subject") != null or
                    std.mem.indexOf(u8, trimmed, "entity1") != null or
                    std.mem.indexOf(u8, trimmed, "head") != null or
                    std.mem.indexOf(u8, trimmed, "source") != null or
                    std.mem.indexOf(u8, trimmed, "sentence") != null)
                {
                    header_skipped = true;
                    continue;
                }
                header_skipped = true;
            }

            // Parse CSV line
            if (self.parseCSVLine(line)) |triple| {
                try triples.append(triple);
            } else |err| {
                print("⚠️  Warning: Failed to parse line {}: '{s}' ({})\n", .{ line_count, line, err });
            }
        }

        print("📊 Parsed {} triples from {} lines\n", .{ triples.items.len, line_count });
        return triples;
    }

    /// Parse a single CSV line into a knowledge triple
    fn parseCSVLine(self: *Self, line: []const u8) !KnowledgeTriple {
        const trimmed = std.mem.trim(u8, line, " \t\r\n");
        if (trimmed.len == 0) return error.EmptyLine;

        var parts = std.mem.splitSequence(u8, trimmed, ",");

        // Handle different CSV formats:
        // Format 1: subject,predicate,object
        // Format 2: sentence,source,target,relation (skip sentence, source=subject, target=object, relation=predicate)

        const first_part = parts.next() orelse return error.MissingFirstColumn;
        const second_part = parts.next() orelse return error.MissingSecondColumn;
        const third_part = parts.next() orelse return error.MissingThirdColumn;
        const fourth_part = parts.next(); // Optional fourth column

        var subject: []const u8 = undefined;
        var predicate: []const u8 = undefined;
        var object: []const u8 = undefined;

        if (fourth_part != null) {
            // 4-column format: sentence,source,target,relation
            subject = second_part; // source
            object = third_part; // target
            predicate = fourth_part.?; // relation
        } else {
            // 3-column format: subject,predicate,object
            subject = first_part;
            predicate = second_part;
            object = third_part;
        }

        // Clean and validate parts
        const clean_subject = std.mem.trim(u8, subject, " \t\"");
        const clean_predicate = std.mem.trim(u8, predicate, " \t\"");
        const clean_object = std.mem.trim(u8, object, " \t\"");

        if (clean_subject.len == 0 or clean_predicate.len == 0 or clean_object.len == 0) {
            return error.EmptyField;
        }

        // Duplicate strings to ensure they're owned by our allocator
        const owned_subject = try self.allocator.dupe(u8, clean_subject);
        const owned_predicate = try self.allocator.dupe(u8, clean_predicate);
        const owned_object = try self.allocator.dupe(u8, clean_object);

        return KnowledgeTriple{
            .subject = owned_subject,
            .predicate = owned_predicate,
            .object = owned_object,
        };
    }

    /// Load parsed triples into NenDB
    pub fn loadIntoDatabase(self: *Self, db: anytype, triples: []const KnowledgeTriple) !void {
        print("🔄 Loading {} triples into NenDB...\n", .{triples.len});

        var timer = try std.time.Timer.start();
        var relationships_created: u32 = 0;

        for (triples, 0..) |triple, i| {
            // Create subject entity
            const subject_id = try self.getOrCreateEntity(db, triple.subject);

            // Create object entity
            const object_id = try self.getOrCreateEntity(db, triple.object);

            // Skip self-loops as NenDB doesn't support them yet
            if (subject_id == object_id) {
                // Note: we could add a counter here if needed for statistics
                continue;
            }

            // Create relationship edge - use hash of predicate as label
            const predicate_hash = std.hash_map.hashString(triple.predicate);
            const label = @as(u32, @truncate(predicate_hash));
            try db.insert_edge(subject_id, object_id, label);
            relationships_created += 1;

            // Progress indicator
            if ((i + 1) % 1000 == 0) {
                print("  Processed {}/{} triples...\n", .{ i + 1, triples.len });
            }
        }

        const load_time = timer.read();
        print("✅ Loaded knowledge graph with {} relationships in {d:.2}ms\n", .{ relationships_created, @as(f64, @floatFromInt(load_time)) / 1_000_000.0 });
    }

    /// Get existing entity ID or create new entity
    fn getOrCreateEntity(self: *Self, db: anytype, entity_name: []const u8) !u64 {
        _ = self; // Currently unused but kept for future string data storage
        // Simple hash-based ID generation (in production, use proper ID management)
        const hash = std.hash_map.hashString(entity_name);
        const entity_id = @as(u64, @intCast(hash)) % 999999; // Keep IDs under 1M

        // Check if entity already exists
        if (db.lookup_node(entity_id)) |_| {
            return entity_id;
        } else {
            // Create new entity
            try db.insert_node(entity_id, 1); // Kind 1 = entity
            return entity_id;
        }
    }

    /// Free allocated triple data
    pub fn freeTriples(self: *Self, triples: std.array_list.Managed(KnowledgeTriple)) void {
        for (triples.items) |triple| {
            self.allocator.free(triple.subject);
            self.allocator.free(triple.predicate);
            self.allocator.free(triple.object);
        }
        triples.deinit();
    }
};
