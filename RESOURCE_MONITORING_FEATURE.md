# 🚀 NenDB Built-in Resource Monitoring

## Overview

NenDB now includes **built-in resource monitoring** that provides real-time insights into CPU, memory, and database performance metrics. This feature addresses the resource measurement limitations we identified in our benchmarking and gives you accurate, real-time data directly from within the database.

## ✨ Key Features

### 🔍 **Real-Time Resource Tracking**
- **CPU Usage**: Current CPU percentage and time breakdown
- **Memory Usage**: RSS, virtual, heap, and memory pools
- **Database Metrics**: Nodes, edges, embeddings, WAL entries
- **Performance**: Operations per second, average latency
- **System Resources**: Disk I/O, network connections

### 📊 **Multiple Output Formats**
- **Human-readable**: Real-time terminal display
- **JSON**: Machine-readable format for APIs
- **Prometheus**: Industry-standard metrics for monitoring systems
- **CSV**: Data export for analysis

### 🕒 **Historical Data**
- Configurable history size (default: 1000 entries)
- Time-based averaging and analysis
- Performance trend tracking

## 🏗️ Architecture

### **Core Components**

1. **ResourceMonitor** (`src/monitoring/resource_monitor.zig`)
   - Main monitoring engine
   - Stats collection and history management
   - Export functionality

2. **Platform Resources** (`src/monitoring/platform_resources.zig`)
   - Cross-platform resource measurement
   - macOS, Linux, and Windows support
   - Process-specific vs system-wide metrics

3. **CLI Integration** (`src/monitoring/cli_monitor.zig`)
   - Command-line monitoring interface
   - Real-time updates and formatting
   - Integration with main NenDB CLI

## 🚀 Usage Examples

### **Basic Resource Monitoring**

```zig
// Initialize resource monitor
var monitor = ResourceMonitor.init(allocator, 1000);
defer monitor.deinit();

// Record operations
monitor.recordOperation();

// Update database stats
monitor.updateDatabaseStats(1000, 500, 200, 150, 25);

// Get current stats
const stats = monitor.getCurrentStats();
```

### **Command Line Usage**

```bash
# Monitor resources in real-time
nen monitor

# Export to JSON format
nen monitor --format json

# Export to Prometheus format
nen monitor --format prometheus

# Custom refresh interval
nen monitor --interval 5

# Limited iterations
nen monitor --iterations 20
```

### **Integration with Database Operations**

```zig
// In your database operations
pub fn createNode(self: *Database, data: []const u8) !NodeId {
    // Record operation for monitoring
    self.resource_monitor.recordOperation();
    
    // Perform actual operation
    const node = try self.actualCreateNode(data);
    
    // Update monitoring stats
    self.resource_monitor.updateDatabaseStats(
        self.node_count,
        self.edge_count,
        self.embedding_count,
        self.wal_entry_count,
        self.wal_size_mb
    );
    
    return node.id;
}
```

## 📈 Metrics Available

### **Performance Metrics**
- **Operations per second**: Real-time throughput
- **Average latency**: Response time per operation
- **Uptime**: Database running time

### **Resource Metrics**
- **CPU Usage**: Process-specific CPU consumption
- **Memory RSS**: Resident set size in MB
- **Memory Virtual**: Virtual memory allocation
- **Memory Heap**: Heap memory usage
- **Memory Pools**: Static memory pool usage

### **Database Metrics**
- **Nodes**: Total nodes in database
- **Edges**: Total edges/relationships
- **Embeddings**: Vector embeddings stored
- **WAL Entries**: Write-ahead log entries
- **WAL Size**: Write-ahead log size in MB

## 🔧 Configuration

### **History Size**
```zig
// Keep last 1000 resource snapshots
var monitor = ResourceMonitor.init(allocator, 1000);
```

### **Refresh Intervals**
```bash
# Update every 5 seconds
nen monitor --interval 5

# Update every 100ms (for high-frequency monitoring)
nen monitor --interval 0.1
```

### **Output Formats**
- `human`: Real-time terminal display
- `json`: Machine-readable JSON
- `prometheus`: Prometheus metrics format
- `csv`: Comma-separated values

## 🌐 Platform Support

### **macOS**
- Uses `mach_task_basic_info` for process metrics
- Memory and CPU time tracking
- System-wide CPU usage via sysctl

### **Linux**
- Reads `/proc/self/stat` for CPU times
- Reads `/proc/self/status` for memory info
- Reads `/proc/self/io` for disk I/O

### **Windows**
- Uses `GetProcessTimes` for CPU metrics
- Uses `GetProcessMemoryInfo` for memory
- Uses `GetProcessIoCounters` for I/O

## 📊 Export Formats

### **JSON Export**
```json
{
  "cpu_percent": 15.2,
  "memory_rss_mb": 512,
  "memory_virtual_mb": 1024,
  "nodes_allocated": 10000,
  "edges_allocated": 25000,
  "operations_per_second": 15000,
  "average_latency_ms": 0.067,
  "uptime_seconds": 3600.5
}
```

### **Prometheus Export**
```prometheus
# HELP nendb_cpu_percent CPU usage percentage
# TYPE nendb_cpu_percent gauge
nendb_cpu_percent 15.2

# HELP nendb_memory_rss_mb Resident set size in MB
# TYPE nendb_memory_rss_mb gauge
nendb_memory_rss_mb 512

# HELP nendb_operations_per_second Operations per second
# TYPE nendb_operations_per_second gauge
nendb_operations_per_second 15000
```

## 🎯 Use Cases

### **Production Monitoring**
- Real-time performance tracking
- Resource usage alerts
- Capacity planning
- Performance optimization

### **Development & Testing**
- Benchmark validation
- Performance regression detection
- Resource leak detection
- Optimization measurement

### **Operations**
- Prometheus integration
- Grafana dashboards
- Alerting systems
- Capacity management

## 🔬 Testing

### **Run Tests**
```bash
# Run all tests including resource monitoring
zig build test

# Run specific resource monitoring tests
zig test tests/test_resource_monitor.zig
```

### **Demo**
```bash
# Run resource monitoring demo
zig build monitor-demo
```

## 🚀 Future Enhancements

### **Planned Features**
1. **GPU Monitoring**: CUDA/OpenCL resource tracking
2. **Network Metrics**: Connection pooling and throughput
3. **Disk I/O**: Detailed storage performance metrics
4. **Custom Metrics**: User-defined monitoring points
5. **Alerting**: Threshold-based notifications
6. **Distributed Monitoring**: Multi-node cluster metrics

### **Integration Opportunities**
1. **Grafana Dashboards**: Pre-built monitoring dashboards
2. **Alert Manager**: Prometheus alerting integration
3. **Log Aggregation**: Structured logging with metrics
4. **APM Integration**: Application performance monitoring

## 💡 Benefits

### **Accuracy**
- **Process-specific metrics** instead of system-wide
- **Real-time data** from within the database
- **No external dependencies** for basic monitoring

### **Performance**
- **Minimal overhead** during operation recording
- **Efficient history management** with configurable limits
- **Fast export** in multiple formats

### **Production Ready**
- **Cross-platform support** for major operating systems
- **Industry-standard formats** (Prometheus, JSON)
- **Configurable and extensible** architecture

## 🎉 Conclusion

NenDB's built-in resource monitoring provides **accurate, real-time insights** into database performance and resource usage. This addresses the measurement limitations we identified in our benchmarking and gives you the tools to:

1. **Monitor production performance** in real-time
2. **Validate benchmark results** with actual data
3. **Optimize resource usage** based on real metrics
4. **Integrate with monitoring systems** (Prometheus, Grafana)
5. **Track performance trends** over time

The system is designed to be **lightweight, accurate, and production-ready**, providing the resource monitoring capabilities needed for serious database deployments.

---

*Feature Status: ✅ Implemented and Tested*  
*Platform Support: ✅ macOS, Linux, Windows*  
*Production Ready: ✅ Yes*  
*Documentation: ✅ Complete*
