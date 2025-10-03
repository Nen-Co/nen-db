# NenDB Benchmarks

This directory contains benchmarking tools and comparisons for NenDB.

## Available Benchmarks

### 1. KuzuDB Comparison (`kuzu_comparison.py`)

Compares NenDB performance against KuzuDB, a mature embedded graph database.

**Requirements:**
```bash
pip install kuzu requests
```

**Usage:**
```bash
# Start NenDB server
nendb serve

# Run comparison (in another terminal)
python benchmarks/kuzu_comparison.py
```

**What it measures:**
- Node insertion speed
- Edge insertion speed
- Graph traversal performance
- Algorithm execution time

### 2. Memory Usage Analysis

**Requirements:**
```bash
pip install psutil
```

**Usage:**
```bash
python benchmarks/memory_analysis.py
```

### 3. Load Testing

**Requirements:**
```bash
pip install locust
```

**Usage:**
```bash
locust -f benchmarks/load_test.py --host=http://localhost:8080
```

## Benchmark Results

Results are stored in `results/` directory with timestamps.

## Adding New Benchmarks

1. Create a new Python file in `benchmarks/`
2. Follow the existing pattern for timing and measurement
3. Add documentation to this README
4. Include requirements in `requirements-benchmarks.txt`

## Performance Targets

Based on KuzuDB benchmarks, our targets are:

- **Node Insertion**: < 1ms per 1000 nodes
- **Edge Traversal**: < 10ms for 10K edge graph
- **Memory Usage**: < 100MB for 1M nodes
- **Startup Time**: < 100ms

## Continuous Benchmarking

Benchmarks run automatically in CI/CD pipeline to track performance regressions.
