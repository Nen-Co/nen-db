# NenDB Configuration

This directory contains configuration files, templates, and examples for NenDB.

## Configuration Files

### Runtime Configuration
- **nendb.conf**: Main configuration file
- **logging.conf**: Logging configuration
- **performance.conf**: Performance tuning parameters

### Build Configuration
- **build.zig**: Main build configuration
- **build_options.zig**: Build-time options and flags
- **targets.zig**: Target-specific configurations

### Development Configuration
- **dev.conf**: Development environment settings
- **test.conf**: Test configuration and parameters
- **bench.conf**: Benchmark configuration

## Configuration Options

### Memory Configuration
```zig
// Memory pool sizes
NENDB_NODE_POOL_SIZE = 4096
NENDB_EDGE_POOL_SIZE = 4096
NENDB_EMBEDDING_POOL_SIZE = 1024

// Cache line alignment
NENDB_CACHE_LINE_SIZE = 64
NENDB_SECTOR_SIZE = 512
NENDB_PAGE_SIZE = 4096
```

### Performance Configuration
```zig
// Performance tuning
NENDB_PREFETCH_DISTANCE = 16
NENDB_HASH_TABLE_LOAD_FACTOR = 0.75
NENDB_BLOOM_FILTER_BITS = 8
NENDB_COMPRESSION_LEVEL = 1
```

### Storage Configuration
```zig
// WAL settings
NENDB_WAL_SEGMENT_SIZE = 1048576  // 1MB
NENDB_WAL_MAX_SEGMENTS = 1024
NENDB_SNAPSHOT_INTERVAL = 10000
NENDB_SYNC_INTERVAL = 100
```

## Environment Variables

```bash
# Set configuration via environment
export NENDB_NODE_POOL_SIZE=8192
export NENDB_EDGE_POOL_SIZE=8192
export NENDB_DATA_DIR="/var/lib/nendb"
export NENDB_LOG_LEVEL="info"
```

## Configuration Precedence

1. **Command line arguments** (highest priority)
2. **Environment variables**
3. **Configuration files**
4. **Compile-time defaults** (lowest priority)

## Best Practices

1. **Performance**: Use static memory pools for predictable performance
2. **Security**: Keep sensitive configuration in environment variables
3. **Flexibility**: Provide sensible defaults for all options
4. **Documentation**: Document all configuration options clearly
5. **Validation**: Validate configuration at startup

## Configuration Validation

NenDB validates configuration at startup:
- Memory pool sizes must be powers of 2
- Performance parameters must be within valid ranges
- Storage paths must be writable
- Network ports must be available
