// NenDB Memory Configuration Generator
// Generates optimal memory configuration based on graph characteristics

const std = @import("std");
const predictor = @import("src/memory/predictor.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 6) {
        std.debug.print("Usage: {s} <nodes> <edges> <profile> <workload> <embedding_dims>\n", .{args[0]});
        std.debug.print("Profiles: sparse, medium, dense, hyper_dense, ai_workload, mixed\n");
        std.debug.print("Workloads: social_network, knowledge_graph, recommendation, ai_training, real_time_analytics, batch_processing\n");
        std.debug.print("Examples:\n");
        std.debug.print("  {s} 100000 500000 sparse social_network 128\n", .{args[0]});
        std.debug.print("  {s} 1000000 10000000 medium knowledge_graph 256\n", .{args[0]});
        std.debug.print("  {s} 500000 5000000 dense ai_training 768\n", .{args[0]});
        return;
    }

    const nodes = try std.fmt.parseInt(u32, args[1], 10);
    const edges = try std.fmt.parseInt(u32, args[2], 10);
    const profile_str = args[3];
    const workload_str = args[4];
    const embedding_dims = try std.fmt.parseInt(u32, args[5], 10);

    const profile = std.meta.stringToEnum(predictor.GraphProfile, profile_str) orelse {
        std.debug.print("Error: Invalid profile '{s}'\n", .{profile_str});
        return;
    };

    const workload = std.meta.stringToEnum(predictor.WorkloadType, workload_str) orelse {
        std.debug.print("Error: Invalid workload '{s}'\n", .{workload_str});
        return;
    };

    const predictor_instance = predictor.MemoryPredictor.init(nodes, edges, profile, workload, embedding_dims);

    // Generate configuration
    const config_file = try std.fmt.allocPrint(allocator, "nendb_config_{s}_{s}_{}_{}.zig", .{ profile_str, workload_str, nodes, edges });
    defer allocator.free(config_file);

    const file = try std.fs.cwd().createFile(config_file, .{});
    defer file.close();

    const writer = file.writer();
    try predictor_instance.generateConfig(writer);

    // Print summary
    std.debug.print("Generated configuration: {s}\n", .{config_file});
    std.debug.print("Memory allocation:\n");
    std.debug.print("  Nodes: {}\n", .{predictor_instance.predictNodePoolSize()});
    std.debug.print("  Edges: {}\n", .{predictor_instance.predictEdgePoolSize()});
    std.debug.print("  Embeddings: {}\n", .{predictor_instance.predictEmbeddingPoolSize()});
    std.debug.print("  Properties: {}\n", .{predictor_instance.predictPropertyPoolSize()});
    std.debug.print("  Total memory: {d:.1f} MB\n", .{@as(f64, @floatFromInt(predictor_instance.estimateTotalMemory())) / 1024.0 / 1024.0});
    std.debug.print("  Utilization: {d:.1f}%\n", .{predictor_instance.getMemoryUtilization() * 100.0});
}
