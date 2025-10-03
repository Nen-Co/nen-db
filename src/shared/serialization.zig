const std = @import("std");

/// Minimal CSV row parser (header-based, static buffer)
pub fn parse_csv_row(line: []const u8, delimiter: u8, out: []?[]const u8) usize {
    var col_start: usize = 0;
    var col_idx: usize = 0;
    var i: usize = 0;
    while (i < line.len and col_idx < out.len) : (i += 1) {
        if (line[i] == delimiter or i == line.len - 1) {
            const end = if (line[i] == delimiter) i else i + 1;
            out[col_idx] = line[col_start..end];
            col_idx += 1;
            col_start = i + 1;
        }
    }
    return col_idx;
}

/// Minimal JSON serializer for Node/Edge arrays (static buffer)
pub fn serialize_nodes_json(nodes: []const @import("graph_types.zig").Node, out: []u8) usize {
    var i: usize = 0;
    var o: usize = 0;
    out[o] = '[';
    o += 1;
    while (i < nodes.len) : (i += 1) {
        if (i > 0) {
            out[o] = ',';
            o += 1;
        }
        const written = std.fmt.bufPrint(out[o..], "{{\"id\":{d}}}", .{nodes[i].id}) catch break;
        o += written.len;
    }
    out[o] = ']';
    o += 1;
    return o;
}

// TODO: Add similar for edges, and more robust error handling as needed.
