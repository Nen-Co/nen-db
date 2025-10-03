const fs = std.fs;
// Streaming CSV loader for large files
pub fn load_csv_into_db(db: *StaticDB, csv_path: []const u8) !void {
    var file = try fs.cwd().openFile(csv_path, .{});
    defer file.close();
    var buf: [4096]u8 = undefined;
    var reader = file.reader(&buf);
    var line_buf: [4096]u8 = undefined;
    var line_len: usize = 0;
    var eof = false;
    var header: ?[]const u8 = null;
    var col_source: usize = 0;
    var col_target: usize = 1;
    var col_label: usize = 2;
    // Read lines one at a time
    while (!eof) {
        // Read a line
        line_len = 0;
        while (true) {
            const n = try reader.read(line_buf[line_len..]);
            if (n == 0) {
                eof = true;
                break;
            }
            var i: usize = 0;
            while (i < n) : (i += 1) {
                const c = line_buf[line_len + i];
                if (c == '\n' or c == '\r') {
                    // End of line
                    break;
                }
            }
            line_len += n;
            if (i < n) break;
        }
        if (line_len == 0) continue;
        const line = line_buf[0..line_len];
        // If header not set, parse header and map columns
        if (header == null) {
            header = line;
            var it = std.mem.splitScalar(u8, line, ',');
            var idx: usize = 0;
            while (it.next()) |col| : (idx += 1) {
                if (std.mem.eql(u8, col, "source")) col_source = idx;
                if (std.mem.eql(u8, col, "target")) col_target = idx;
                if (std.mem.eql(u8, col, "label")) col_label = idx;
            }
            continue;
        }
        // Parse columns using shared CSV row parser
        var cols: [5]?[]const u8 = .{null} ** 5;
        _ = shared_serial.parse_csv_row(line, ',', &cols);
        if (cols[col_source] == null or cols[col_target] == null or cols[col_label] == null) {
            std.debug.print("[csv] ERROR: column index out of bounds: src={} tgt={} lbl={}\n", .{ col_source, col_target, col_label });
            return shared_errors.Error.CsvParseError;
        }
        const source = cols[col_source].?;
        const target = cols[col_target].?;
        const label = cols[col_label].?;
        std.debug.print("[csv] row: source='{s}' target='{s}' label='{s}' nodes={} edges={}\n", .{ source, target, label, db.node_count, db.edge_count });
        // Add nodes (no deduplication for now)
        if (db.node_count < MAX_NODES) {
            const src_label = db.arena.alloc(source.len) catch |e| {
                std.debug.print("[csv] ERROR: src_label alloc failed: {}\n", .{e});
                return e;
            };
            std.mem.copyForwards(u8, src_label, source);
            db.add_node(db.node_count + 1, src_label, 1) catch |e| {
                std.debug.print("[csv] ERROR: add_node src failed: {}\n", .{e});
                return e;
            };
        }
        if (db.node_count < MAX_NODES) {
            const tgt_label = db.arena.alloc(target.len) catch |e| {
                std.debug.print("[csv] ERROR: tgt_label alloc failed: {}\n", .{e});
                return e;
            };
            std.mem.copyForwards(u8, tgt_label, target);
            db.add_node(db.node_count + 1, tgt_label, 1) catch |e| {
                std.debug.print("[csv] ERROR: add_node tgt failed: {}\n", .{e});
                return e;
            };
        }
        // Add edge
        if (db.edge_count < MAX_EDGES) {
            const lbl = db.arena.alloc(label.len) catch |e| {
                std.debug.print("[csv] ERROR: label alloc failed: {}\n", .{e});
                return e;
            };
            std.mem.copyForwards(u8, lbl, label);
            db.add_edge(db.node_count - 1, db.node_count, lbl) catch |e| {
                std.debug.print("[csv] ERROR: add_edge failed: {}\n", .{e});
                return e;
            };
        }
    }
}
// NenDB Embedded - Single-User, Local Database
// Optimized for desktop, mobile, IoT, and single-user applications

const std = @import("std");
const Allocator = std.mem.Allocator;
const nen_io = @import("nen-io");
const NetworkSocket = nen_io.network.NetworkSocket;
const parseAddress = nen_io.network.parseAddress;

const shared = @import("../shared/lib.zig");
const shared_graph = shared.graph_types;
const shared_errors = shared.errors;
const shared_memory = shared.static_memory;
const shared_serial = shared.serialization;

pub const Error = error{ NodeFull, EdgeFull };

// This module implements a static-memory, fixed-capacity embedded graph store
// following the NenWay rules: static allocation at startup, no dynamic
// allocation after init. It exposes a tiny TCP protocol for the visualizer.

pub const MAX_NODES: usize = 1024; // reasonable default for embedded demo
pub const MAX_EDGES: usize = 4096;
pub const TCP_PORT: u16 = 4488;

const Node = shared_graph.Node;
const Edge = shared_graph.Edge;

pub const StaticDB = struct {
    // Buffers are allocated once at startup and owned by the DB
    node_buf: [MAX_NODES]Node,
    edge_buf: [MAX_EDGES]Edge,
    node_count: usize,
    edge_count: usize,
    // visualizer JSON constructed at init time and reused for all requests
    visualizer_json: ?[]const u8,
    // internal arena for runtime allocations (labels, serialization)
    arena_buffer: [64 * 1024]u8,
    arena: shared_memory.FixedBufferArena,

    pub fn init() StaticDB {
        var db: StaticDB = undefined;
        db.node_buf = undefined;
        db.edge_buf = undefined;
        db.node_count = 0;
        db.edge_count = 0;
        db.visualizer_json = null;
        db.arena = shared_memory.FixedBufferArena.init(&db.arena_buffer);
        return db;
    }

    pub fn add_node(self: *StaticDB, id: u64, label: []const u8, group: u8) !void {
        if (self.node_count >= MAX_NODES) return Error.NodeFull;
        const idx = self.node_count;
        // store label as a slice referencing the passed buffer; caller must
        // ensure lifetime (we'll duplicate for demo simplicity using arena)
        self.node_buf[idx] = Node{ .id = id, .label = label, .group = group };
        self.node_count += 1;
    }

    pub fn add_edge(self: *StaticDB, source: u64, target: u64, label: []const u8) !void {
        if (self.edge_count >= MAX_EDGES) return Error.EdgeFull;
        const idx = self.edge_count;
        self.edge_buf[idx] = Edge{ .src = source, .dst = target, .label = label };
        self.edge_count += 1;
    }

    // we build the visualizer JSON as a static sample at startup in `main`
};

pub fn main() !void {
    std.debug.print("🚀 NenDB Embedded (static) - TCP visualizer backend\n", .{});

    var db = StaticDB.init();

    // Load the full CSV dataset into the DB at startup
    try load_csv_into_db(&db, "../nen-visualizer/pancreatic_cancer_kg_original.csv");

    // Serialize DB to JSON for visualizer
    try serialize_visualizer(&db);

    // Start the long-running, multi-client server for the CLI/binary
    try serve_forever(&db, TCP_PORT);
}

// Serve exactly one connection then return — useful for tests.
pub fn serve_single(db: *StaticDB, port: u16) !void {
    var listener = try NetworkSocket.createTcp();
    defer listener.close();
    try listener.configure(.{ .reuse_addr = true, .tcp_nodelay = true, .non_blocking = false, .keep_alive = true });
    const srv_addr = try parseAddress("0.0.0.0", port);
    try listener.bind(srv_addr);
    try listener.listen(1);

    std.debug.print("[test server] Listening on TCP port {}\n", .{port});

    const client = try listener.accept();
    var client_socket = client.socket;
    handle_conn(&client_socket, db) catch |e| {
        std.debug.print("test connection handler error: {}\n", .{e});
    };
    client_socket.close();
}

// Serve forever (used by the binary entrypoint)
pub fn serve_forever(db: *StaticDB, port: u16) !void {
    var listener = try NetworkSocket.createTcp();
    defer listener.close();
    try listener.configure(.{ .reuse_addr = true, .tcp_nodelay = true, .non_blocking = false, .keep_alive = true });
    const srv_addr = try parseAddress("0.0.0.0", port);
    try listener.bind(srv_addr);
    try listener.listen(128);

    std.debug.print("Listening on TCP port {}\n", .{port});

    while (true) {
        const client = try listener.accept();
        var client_socket = client.socket;
        handle_conn(&client_socket, db) catch |e| {
            std.debug.print("connection handler error: {}\n", .{e});
        };
        client_socket.close();
    }
}
fn handle_conn(client: *NetworkSocket, db: *StaticDB) !void {
    var buf: [1024]u8 = undefined;
    const n = try client.receive(&buf);
    const req = buf[0..n];
    const get_cmd = "GET_VISUALIZER";
    if (n > 0 and std.mem.startsWith(u8, req, get_cmd)) {
        if (db.visualizer_json) |s| {
            _ = try client.send(s);
        } else {
            _ = try client.send("{}");
        }
    } else {
        _ = try client.send("ERROR: unknown request\n");
    }
}

fn appendSlice(dest: []u8, pos: *usize, s: []const u8) void {
    const len = s.len;
    // copy into destination at the current position and advance the position
    // manual copy to avoid relying on std.mem.copy API across Zig versions
    var i: usize = 0;
    while (i < len) : (i += 1) {
        dest[pos.* + i] = s[i];
    }
    pos.* += len;
}

fn writeNum(dest: []u8, pos: *usize, num: usize) void {
    var buf: [32]u8 = undefined;
    const s = std.fmt.bufPrint(&buf, "{d}", .{num}) catch "";
    // s points into the stack buffer `buf`; appendSlice copies it into `dest`.
    appendSlice(dest, pos, s);
}

pub fn serialize_visualizer(db: *StaticDB) !void {
    // Use static arena for buffer
    var buf: [16 * 1024]u8 = undefined;
    var pos: usize = 0;

    appendSlice(&buf, &pos, "{\"nodes\":");
    pos += shared_serial.serialize_nodes_json(db.node_buf[0..db.node_count], buf[pos..]);
    appendSlice(&buf, &pos, ",\"edges\":[");
    var first = true;
    for (db.edge_buf[0..db.edge_count]) |edge| {
        if (!first) appendSlice(&buf, &pos, ",");
        first = false;
        appendSlice(&buf, &pos, "{\"source\":\"");
        // Use .src and .dst for shared Edge
        const written = std.fmt.bufPrint(buf[pos..], "{d}", .{edge.src}) catch break;
        pos += written.len;
        appendSlice(&buf, &pos, "\",\"target\":\"");
        const written2 = std.fmt.bufPrint(buf[pos..], "{d}", .{edge.dst}) catch break;
        pos += written2.len;
        appendSlice(&buf, &pos, "\",\"label\":\"");
        appendSlice(&buf, &pos, edge.label);
        appendSlice(&buf, &pos, "\"}");
    }
    appendSlice(&buf, &pos, "],\"metadata\":{");
    appendSlice(&buf, &pos, "\"node_count\":");
    writeNum(&buf, &pos, db.node_count);
    appendSlice(&buf, &pos, ",\"edge_count\":");
    writeNum(&buf, &pos, db.edge_count);
    appendSlice(&buf, &pos, "}}");

    // shrink to actual size and store as a const slice pointing into the DB arena
    db.visualizer_json = buf[0..pos];
}
// end of file
