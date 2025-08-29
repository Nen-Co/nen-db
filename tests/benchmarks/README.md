# NenDB Benchmarks

This directory contains comprehensive benchmark tests for measuring NenDB performance.

## Available Benchmarks

### Core Performance Benchmarks
- **benchmark.zig**: Basic performance benchmarks for core operations
- **real_benchmark.zig**: Real-world scenario performance tests

### Benchmark Categories

#### Node Operations
- Node creation performance
- Node lookup performance
- Node update performance
- Node deletion performance

#### Edge Operations
- Edge creation performance
- Edge traversal performance
- Edge query performance

#### Graph Operations
- Graph traversal performance
- Path finding performance
- Query execution performance

#### Memory Operations
- Memory allocation performance
- Memory pool performance
- Cache performance

## Running Benchmarks

```bash
# Run all benchmarks
zig build bench

# Run specific benchmark
zig build run-benchmark

# Run with performance profiling
zig build profile
```

## Benchmark Standards

### Performance Targets
- **Node operations**: >10k ops/sec
- **Edge operations**: >8k ops/sec
- **Query operations**: <1ms average
- **Memory overhead**: <5% of data size
- **Startup time**: <100ms

### Benchmark Methodology
1. **Warm-up**: Run operations to warm up caches
2. **Measurement**: Measure performance over multiple iterations
3. **Validation**: Ensure results meet performance targets
4. **Reporting**: Generate detailed performance reports

## Benchmark Configuration

Benchmarks can be configured via:
- Command line arguments
- Environment variables
- Configuration files
- Build-time options

## Contributing Benchmarks

When adding new benchmarks:

1. **Follow TDD**: Write tests first
2. **Use NenStyle**: Static memory, zero allocation in hot paths
3. **Performance Focus**: Measure real performance, not synthetic
4. **Documentation**: Clear description of what is being measured
5. **Validation**: Ensure benchmarks are reproducible
