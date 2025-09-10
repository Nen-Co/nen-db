// Minimal working TCP server following Zig 0.15.1 best practices
const std = @import("std");

pub fn main() !void {
    std.debug.print("🚀 Minimal NenDB TCP Server Starting...\n", .{});

    // Create socket
    const listen_socket = try std.posix.socket(std.posix.AF.INET, std.posix.SOCK.STREAM, 0);
    defer std.posix.close(listen_socket);

    // Set socket options
    const enable: c_int = 1;
    try std.posix.setsockopt(listen_socket, std.posix.SOL.SOCKET, std.posix.SO.REUSEADDR, &std.mem.toBytes(enable));

    // Bind to address
    const address = try std.net.Address.parseIp4("127.0.0.1", 5454);
    try std.posix.bind(listen_socket, &address.any, address.getOsSockLen());
    try std.posix.listen(listen_socket, 128);

    std.debug.print("✓ Server listening on 127.0.0.1:5454\n", .{});
    std.debug.print("📡 Accepting connections (Ctrl+C to stop)...\n", .{});

    // Simple accept loop
    while (true) {
        var client_addr: std.net.Address = undefined;
        var addr_len: std.posix.socklen_t = @sizeOf(std.net.Address);

        const client_socket = std.posix.accept(listen_socket, &client_addr.any, &addr_len, 0) catch |err| {
            std.debug.print("Accept error: {}\n", .{err});
            continue;
        };
        defer std.posix.close(client_socket);

        std.debug.print("🔗 Client connected from {any}\n", .{client_addr});

        // Simple echo server
        var buffer: [1024]u8 = undefined;
        const bytes_read = std.posix.read(client_socket, &buffer) catch |err| {
            std.debug.print("Read error: {}\n", .{err});
            continue;
        };

        if (bytes_read == 0) {
            std.debug.print("Client disconnected\n", .{});
            continue;
        }

        std.debug.print("📨 Received: {s}\n", .{buffer[0..bytes_read]});

        // Echo back
        const response = "Echo: ";
        _ = std.posix.write(client_socket, response) catch {};
        _ = std.posix.write(client_socket, buffer[0..bytes_read]) catch {};

        std.debug.print("📤 Echoed back to client\n", .{});
    }
}
