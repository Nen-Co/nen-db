// NenDB TCP Server (minimal, production-style)
// Listens for TCP connections and handles simple text-based commands
// Example protocol: "INSERT_NODE id kind" or "LOOKUP_NODE id"

const std = @import("std");
const graphdb = @import("../graphdb.zig");

pub fn start_server(port: u16) !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var address = try std.net.Address.parseIp4("0.0.0.0", port);
    const posix = std.posix;
    const sockfd = try posix.socket(posix.AF.INET, posix.SOCK.STREAM, 0);
    defer posix.close(sockfd);

    try posix.setsockopt(sockfd, posix.SOL.SOCKET, posix.SO.REUSEADDR, &std.mem.toBytes(@as(c_int, 1)));
    try posix.bind(sockfd, &address.any, address.getOsSockLen());
    try posix.listen(sockfd, 128);

    std.debug.print("NenDB TCP server listening on port {d}\n", .{port});

    var db: graphdb.GraphDB = undefined;
    try graphdb.GraphDB.open_inplace(&db, ".");
    defer db.deinit();

    while (true) {
        var client_addr: std.net.Address = undefined;
        var client_addr_len: posix.socklen_t = @sizeOf(std.net.Address);
        const connfd = try posix.accept(sockfd, &client_addr.any, &client_addr_len, 0);
        std.debug.print("Accepted connection\n", .{});
        // Spawn a thread per connection for simplicity
        const th = try std.Thread.spawn(.{}, client_thread, .{ &db, connfd, allocator });
        th.detach();
    }
}

fn handle_client(db: *graphdb.GraphDB, stream: *std.fs.File, allocator: std.mem.Allocator) !void {
    var buf: [256]u8 = undefined;
    // Simple token-based auth via env var NENDB_AUTH_TOKEN (optional)
    var token: ?[]const u8 = null;
    if (std.process.getEnvVarOwned(std.heap.page_allocator, "NENDB_AUTH_TOKEN")) |val| {
        token = val;
    } else |_| {}
    var authed = token == null; // if no token configured, allow all
    while (true) {
        const n = try stream.read(&buf);
        if (n == 0) break;
        const line = std.mem.trim(u8, buf[0..n], " \r\n");
        if (line.len == 0) continue; // Ignore empty lines
        if (!authed) {
            if (std.mem.startsWith(u8, line, "AUTH ")) {
                const supplied = std.mem.trim(u8, line[5..], " ");
                if (token) |t| {
                    if (std.mem.eql(u8, supplied, t)) {
                        authed = true;
                        _ = try stream.write("OK\n");
                        continue;
                    }
                }
                _ = try stream.write("ERR\n");
                continue;
            } else {
                _ = try stream.write("NOAUTH\n");
                continue;
            }
        }
        if (std.mem.startsWith(u8, line, "INSERT_NODE ")) {
            // Example: INSERT_NODE 42 1
            var it = std.mem.tokenizeAny(u8, line[12..], " ");
            const id_str = it.next() orelse null;
            const kind_str = it.next() orelse null;
            if (id_str == null or kind_str == null) {
                _ = try stream.write("ERR\n");
                continue;
            }
            const id = std.fmt.parseInt(u64, id_str.?, 10) catch {
                _ = try stream.write("ERR\n");
                continue;
            };
            const kind = std.fmt.parseInt(u8, kind_str.?, 10) catch {
                _ = try stream.write("ERR\n");
                continue;
            };
            const node = graphdb.pool.Node{
                .id = id,
                .kind = kind,
                .props = [_]u8{0} ** graphdb.constants.data.node_props_size,
            };
            db.insert_node(node) catch {
                _ = try stream.write("ERR\n");
                continue;
            };
            _ = try stream.write("OK\n");
        } else if (std.mem.startsWith(u8, line, "LOOKUP_NODE ")) {
            // Example: LOOKUP_NODE 42
            const id_str = std.mem.trim(u8, line[11..], " ");
            const id = std.fmt.parseInt(u64, id_str, 10) catch {
                _ = try stream.write("ERR\n");
                continue;
            };
            if (db.lookup_node(id)) |node| {
                const out = try std.fmt.allocPrint(allocator, "FOUND {d} {d}\n", .{ node.id, node.kind });
                defer allocator.free(out);
                _ = try stream.write(out);
            } else {
                _ = try stream.write("NOT_FOUND\n");
            }
        } else if (std.mem.eql(u8, line, "PING")) {
            _ = try stream.write("PONG\n");
        } else if (std.mem.eql(u8, line, "QUIT")) {
            _ = try stream.write("BYE\n");
            return;
        } else {
            _ = try stream.write("ERR\n");
        }
    }
}

fn client_thread(db: *graphdb.GraphDB, connfd: std.posix.fd_t, allocator: std.mem.Allocator) !void {
    var file = std.fs.File{ .handle = connfd };
    defer std.posix.close(connfd);
    handle_client(db, &file, allocator) catch |err| {
        std.debug.print("Client error: {}\n", .{err});
    };
}
