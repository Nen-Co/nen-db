const std = @import("std");

// Hermetic smoke test: start a tiny one-connection TCP server in-thread,
// connect with a client and validate GET_VISUALIZER returns JSON.
pub fn main() !void {
    const nen_io = @import("nen-io");
    const NetworkSocket = nen_io.network.NetworkSocket;

    // server thread
    var server_thread = try std.Thread.spawn(.{}, server_thread_fn, .{null});
    defer server_thread.join();

    // wait until server is listening (simple probe loop)
    const addr = try nen_io.network.parseAddress("127.0.0.1", 4488);
    var attempt: u32 = 0;
    var connected = false;
    while (attempt < 40) : (attempt += 1) {
        // sleep 25ms using Thread.sleep with nanosecond units
        std.Thread.sleep(25 * std.time.ns_per_ms);
        var probe = NetworkSocket.createTcp() catch continue;
        // use `catch` to handle the error union returned by connect()
        probe.connect(addr) catch {
            _ = probe.close();
            continue;
        };
        _ = probe.close();
        connected = true;
        break;
    }
    if (!connected) return error.ConnectionFailed;

    // real client
    var conn = try NetworkSocket.createTcp();
    defer conn.close();
    try conn.connect(addr);
    _ = try conn.send("GET_VISUALIZER\n");
    var buf: [8192]u8 = undefined;
    const n = try conn.receive(&buf);
    const resp = buf[0..n];
    if (n == 0) return error.EmptyResponse;
    // minimal validation: must start with '{'
    if (resp[0] != '{') return error.MalformedResponse;
    std.debug.print("smoke test received {} bytes\n", .{n});
}

fn server_thread_fn(_: ?*u8) void {
    const nen_io = @import("nen-io");
    const NetworkSocket = nen_io.network.NetworkSocket;
    std.debug.print("[smoke server] thread start\n", .{});
    const listen_addr = nen_io.network.parseAddress("0.0.0.0", 4488) catch {
        std.debug.print("[smoke server] parseAddress failed\n", .{});
        return;
    };
    var listener = NetworkSocket.createTcp() catch {
        std.debug.print("[smoke server] createTcp failed\n", .{});
        return;
    };
    defer listener.close();
    listener.configure(.{ .reuse_addr = true, .tcp_nodelay = true, .non_blocking = false, .keep_alive = true }) catch {
        std.debug.print("[smoke server] configure failed\n", .{});
        return;
    };
    listener.bind(listen_addr) catch {
        std.debug.print("[smoke server] bind failed\n", .{});
        return;
    };
    listener.listen(1) catch {
        std.debug.print("[smoke server] listen failed\n", .{});
        return;
    };
    std.debug.print("[smoke server] listening on port 4488\n", .{});

    const sample = "{\"nodes\":[],\"edges\":[],\"metadata\":{\"node_count\":0,\"edge_count\":0}}";

    const client = listener.accept() catch return;
    var client_socket = client.socket;
    defer client_socket.close();

    var buf: [1024]u8 = undefined;
    const n = client_socket.receive(&buf) catch {
        std.debug.print("[smoke server] receive failed\n", .{});
        return;
    };
    const req = buf[0..n];
    if (std.mem.startsWith(u8, req, "GET_VISUALIZER")) {
        std.debug.print("[smoke server] got GET_VISUALIZER, sending sample\n", .{});
        _ = client_socket.send(sample) catch {
            std.debug.print("[smoke server] send failed\n", .{});
            return;
        };
    } else {
        _ = client_socket.send("ERROR") catch return;
    }
    std.debug.print("[smoke server] done\n", .{});
}
