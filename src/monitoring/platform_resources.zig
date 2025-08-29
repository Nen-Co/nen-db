// Platform-specific resource monitoring implementations
// Provides real CPU and memory usage data

const std = @import("std");
const time = std.time;
const os = std.os;
const mem = std.mem;

pub const CpuInfo = struct {
    percent: f64,
    user_time: f64,
    system_time: f64,
};

pub const MemoryInfo = struct {
    rss_mb: u64,
    virtual_mb: u64,
    heap_mb: u64,
};

pub const DiskIoInfo = struct {
    read_mb: u64,
    write_mb: u64,
};

pub fn getCpuUsage() ?CpuInfo {
    return switch (os.target.os.tag) {
        .macos => getCpuUsageMacos(),
        .linux => getCpuUsageLinux(),
        .windows => getCpuUsageWindows(),
        else => null,
    };
}

pub fn getMemoryUsage() ?MemoryInfo {
    return switch (os.target.os.tag) {
        .macos => getMemoryUsageMacos(),
        .linux => getMemoryUsageLinux(),
        .windows => getMemoryUsageWindows(),
        else => null,
    };
}

pub fn getDiskIo() ?DiskIoInfo {
    return switch (os.target.os.tag) {
        .macos => getDiskIoMacos(),
        .linux => getDiskIoLinux(),
        .windows => getDiskIoWindows(),
        else => null,
    };
}

// macOS Implementation
fn getCpuUsageMacos() ?CpuInfo {
    // Use mach_task_basic_info for process-specific CPU usage
    const task_info = os.darwin.mach_task_basic_info;
    var info: task_info = undefined;
    var count = task_info.count;

    const result = os.darwin.mach.task_info(
        os.darwin.mach.task_self(),
        os.darwin.mach.TASK_BASIC_INFO,
        &info,
        &count,
    );

    if (result != os.darwin.mach.KERN_SUCCESS) {
        return null;
    }

    // Calculate CPU percentage (simplified)
    const now = time.nanoTimestamp();
    const cpu_time = @as(f64, @floatFromInt(info.user_time.seconds)) +
        @as(f64, @floatFromInt(info.user_time.microseconds)) / 1_000_000.0;

    return CpuInfo{
        .percent = 0.0, // Would need more complex calculation
        .user_time = cpu_time,
        .system_time = 0.0, // Not available in basic info
    };
}

fn getMemoryUsageMacos() ?MemoryInfo {
    const task_info = os.darwin.mach_task_basic_info;
    var info: task_info = undefined;
    var count = task_info.count;

    const result = os.darwin.mach.task_info(
        os.darwin.mach.task_self(),
        os.darwin.mach.TASK_BASIC_INFO,
        &info,
        &count,
    );

    if (result != os.darwin.mach.KERN_SUCCESS) {
        return null;
    }

    return MemoryInfo{
        .rss_mb = info.resident_size / (1024 * 1024),
        .virtual_mb = info.virtual_size / (1024 * 1024),
        .heap_mb = 0, // Would need heap-specific info
    };
}

fn getDiskIoMacos() ?DiskIoInfo {
    // macOS doesn't provide easy access to per-process disk I/O
    // Would need to use IOKit or other system APIs
    return null;
}

// Linux Implementation
fn getCpuUsageLinux() ?CpuInfo {
    // Read /proc/self/stat for process CPU times
    const file = std.fs.cwd().openFile("/proc/self/stat", .{}) catch return null;
    defer file.close();

    var buffer: [1024]u8 = undefined;
    const bytes_read = file.read(&buffer) catch return null;
    const content = buffer[0..bytes_read];

    // Parse stat file for CPU times (fields 14 and 15)
    var iter = mem.split(u8, content, " ");
    var field_count: u32 = 0;
    var user_time: u64 = 0;
    var system_time: u64 = 0;

    while (iter.next()) |field| {
        field_count += 1;
        if (field_count == 14) {
            user_time = std.fmt.parseInt(u64, field, 10) catch 0;
        } else if (field_count == 15) {
            system_time = std.fmt.parseInt(u64, field, 10) catch 0;
            break;
        }
    }

    // Convert clock ticks to seconds (typically 100 Hz)
    const clock_ticks_per_second: f64 = 100.0;

    return CpuInfo{
        .percent = 0.0, // Would need more complex calculation
        .user_time = @as(f64, @floatFromInt(user_time)) / clock_ticks_per_second,
        .system_time = @as(f64, @floatFromInt(system_time)) / clock_ticks_per_second,
    };
}

fn getMemoryUsageLinux() ?MemoryInfo {
    // Read /proc/self/status for memory information
    const file = std.fs.cwd().openFile("/proc/self/status", .{}) catch return null;
    defer file.close();

    var buffer: [4096]u8 = undefined;
    const bytes_read = file.read(&buffer) catch return null;
    const content = buffer[0..bytes_read];

    var rss_mb: u64 = 0;
    var virtual_mb: u64 = 0;

    var lines = mem.split(u8, content, "\n");
    while (lines.next()) |line| {
        if (mem.startsWith(u8, line, "VmRSS:")) {
            const parts = mem.split(u8, line, " ");
            if (parts.next()) |_| {
                if (parts.next()) |value| {
                    rss_mb = std.fmt.parseInt(u64, value, 10) catch 0;
                }
            }
        } else if (mem.startsWith(u8, line, "VmSize:")) {
            const parts = mem.split(u8, line, " ");
            if (parts.next()) |_| {
                if (parts.next()) |value| {
                    virtual_mb = std.fmt.parseInt(u64, value, 10) catch 0;
                }
            }
        }
    }

    return MemoryInfo{
        .rss_mb = rss_mb,
        .virtual_mb = virtual_mb,
        .heap_mb = 0, // Would need heap-specific info
    };
}

fn getDiskIoLinux() ?DiskIoInfo {
    // Read /proc/self/io for process disk I/O
    const file = std.fs.cwd().openFile("/proc/self/io", .{}) catch return null;
    defer file.close();

    var buffer: [512]u8 = undefined;
    const bytes_read = file.read(&buffer) catch return null;
    const content = buffer[0..bytes_read];

    var read_bytes: u64 = 0;
    var write_bytes: u64 = 0;

    var lines = mem.split(u8, content, "\n");
    while (lines.next()) |line| {
        if (mem.startsWith(u8, line, "rchar:")) {
            const parts = mem.split(u8, line, " ");
            if (parts.next()) |_| {
                if (parts.next()) |value| {
                    read_bytes = std.fmt.parseInt(u64, value, 10) catch 0;
                }
            }
        } else if (mem.startsWith(u8, line, "wchar:")) {
            const parts = mem.split(u8, line, " ");
            if (parts.next()) |_| {
                if (parts.next()) |value| {
                    write_bytes = std.fmt.parseInt(u64, value, 10) catch 0;
                }
            }
        }
    }

    return DiskIoInfo{
        .read_mb = read_bytes / (1024 * 1024),
        .write_mb = write_bytes / (1024 * 1024),
    };
}

// Windows Implementation
fn getCpuUsageWindows() ?CpuInfo {
    // Windows implementation would use GetProcessTimes
    // For now, return null to indicate not implemented
    return null;
}

fn getMemoryUsageWindows() ?MemoryInfo {
    // Windows implementation would use GetProcessMemoryInfo
    // For now, return null to indicate not implemented
    return null;
}

fn getDiskIoWindows() ?DiskIoInfo {
    // Windows implementation would use GetProcessIoCounters
    // For now, return null to indicate not implemented
    return null;
}

// Utility functions for calculating CPU percentage
pub fn calculateCpuPercentage(prev_user: u64, prev_system: u64, prev_idle: u64, curr_user: u64, curr_system: u64, curr_idle: u64) f64 {
    const user_diff = curr_user - prev_user;
    const system_diff = curr_system - prev_system;
    const idle_diff = curr_idle - prev_idle;

    const total_diff = user_diff + system_diff + idle_diff;
    if (total_diff == 0) return 0.0;

    const cpu_diff = user_diff + system_diff;
    return @as(f64, @floatFromInt(cpu_diff)) / @as(f64, @floatFromInt(total_diff)) * 100.0;
}

// System-wide CPU usage (useful for comparison)
pub fn getSystemCpuUsage() ?f64 {
    return switch (os.target.os.tag) {
        .macos => getSystemCpuUsageMacos(),
        .linux => getSystemCpuUsageLinux(),
        .windows => getSystemCpuUsageWindows(),
        else => null,
    };
}

fn getSystemCpuUsageMacos() ?f64 {
    // Read system CPU usage from sysctl
    var size: usize = 4;
    var cpu_count: u32 = 0;

    const result = os.darwin.sysctlbyname("hw.ncpu", &cpu_count, &size, null, 0);
    if (result != 0) return null;

    // This is a simplified version - would need more complex calculation
    return 0.0;
}

fn getSystemCpuUsageLinux() ?f64 {
    // Read /proc/stat for system CPU usage
    const file = std.fs.cwd().openFile("/proc/stat", .{}) catch return null;
    defer file.close();

    var buffer: [256]u8 = undefined;
    const bytes_read = file.read(&buffer) catch return null;
    const content = buffer[0..bytes_read];

    // Parse first line (total CPU)
    if (mem.indexOf(u8, content, "\n")) |newline_pos| {
        const cpu_line = content[0..newline_pos];
        if (mem.startsWith(u8, cpu_line, "cpu ")) {
            var parts = mem.split(u8, cpu_line, " ");
            _ = parts.next(); // Skip "cpu"

            var values: [4]u64 = undefined;
            var i: usize = 0;
            while (parts.next()) |part| : (i += 1) {
                if (i < 4) {
                    values[i] = std.fmt.parseInt(u64, part, 10) catch 0;
                }
            }

            // Calculate CPU percentage (simplified)
            const total = values[0] + values[1] + values[2] + values[3];
            const idle = values[3];
            if (total > 0) {
                return @as(f64, @floatFromInt(total - idle)) / @as(f64, @floatFromInt(total)) * 100.0;
            }
        }
    }

    return null;
}

fn getSystemCpuUsageWindows() ?f64 {
    // Windows implementation would use GetSystemTimes
    return null;
}
