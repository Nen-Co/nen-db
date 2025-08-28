// NenDB TCP Server (minimal, production-style)
// Listens for TCP connections and handles simple text-based commands
// Example protocol: "INSERT_NODE id kind" or "LOOKUP_NODE id"

const std = @import("std");

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

    while (true) {
        var client_addr: std.net.Address = undefined;
        var client_addr_len: posix.socklen_t = @sizeOf(std.net.Address);
        const connfd = try posix.accept(sockfd, &client_addr.any, &client_addr_len, 0);
        std.debug.print("Accepted connection from {}\n", .{client_addr});
        // Spawn a thread per connection for simplicity
        const th = try std.Thread.spawn(.{}, handle_client, .{ connfd, allocator });
        th.detach();
    }
}

fn handle_client(connfd: std.posix.fd_t, allocator: std.mem.Allocator) !void {
    _ = allocator; // Suppress unused parameter warning
    // Convert file descriptor to a stream
    const stream = std.fs.File{ .handle = connfd };
    defer stream.close();

    var buf: [256]u8 = undefined;

    // Send welcome message
    _ = try stream.write("NenDB Server Ready\n");

    while (true) {
        const n = try stream.read(&buf);
        if (n == 0) break;
        const line = std.mem.trim(u8, buf[0..n], " \r\n");
        if (line.len == 0) continue; // Ignore empty lines

        if (std.mem.eql(u8, line, "PING")) {
            _ = try stream.write("PONG\n");
        } else if (std.mem.eql(u8, line, "QUIT")) {
            _ = try stream.write("BYE\n");
            return;
        } else if (std.mem.eql(u8, line, "STATUS")) {
            _ = try stream.write("Server running, no database access\n");
        } else {
            _ = try stream.write("ERR\n");
        }
    }
}
