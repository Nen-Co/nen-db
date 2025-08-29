# NenDB Development Tools

This directory contains development tools, utilities, and scripts for working with NenDB.

## Available Tools

### Performance Tools
- **Performance Profiler**: Built-in performance analysis and bottleneck detection
- **Memory Analyzer**: Memory usage analysis and leak detection
- **Benchmark Suite**: Comprehensive performance benchmarking

### Development Tools
- **Code Generators**: Generate boilerplate code following NenStyle standards
- **Test Utilities**: Helper functions for writing tests
- **Documentation Generators**: Auto-generate documentation from code

### Maintenance Tools
- **Database Maintenance**: WAL compaction, snapshot management
- **Health Checkers**: System health monitoring and diagnostics
- **Migration Tools**: Database schema and data migration utilities

## Using the Tools

```bash
# Run performance profiling
zig build profile

# Run memory analysis
zig build memory

# Run benchmarks
zig build bench

# Run all tests
zig build test-all
```

## Tool Development Standards

When adding new tools:

1. **Follow TDD**: Write tests for tool functionality
2. **Use NenStyle**: Static memory, zero allocation in hot paths
3. **Performance First**: Tools should be fast and efficient
4. **Documentation**: Clear usage instructions and examples
5. **Integration**: Work seamlessly with the main build system

## Tool Categories

### Core Tools (Built-in)
- Performance profiling
- Memory analysis
- Benchmarking
- Testing infrastructure

### Utility Tools (Optional)
- Code generation
- Documentation generation
- Database maintenance
- Health monitoring

### External Tools (Third-party)
- IDE integrations
- CI/CD tools
- Monitoring dashboards
- Performance analysis tools
