# NenDB Repository Organization

This document describes the organization and structure of the NenDB repository.

## 📁 Directory Structure

```
nendb/
├── src/                    # Source code
│   ├── main.zig           # Main entry point
│   ├── lib.zig            # Library exports
│   ├── constants.zig      # Configuration constants
│   ├── graphdb.zig        # Core graph database
│   ├── wal.zig            # Write-ahead logging
│   ├── memory/            # Memory management
│   ├── io/                # I/O operations
│   ├── query/             # Query engine
│   ├── monitoring/        # Resource monitoring
│   ├── cli/               # Command line interface
│   └── api/               # API layer
├── tests/                  # Test infrastructure
│   ├── unit/              # Unit tests (fast, isolated)
│   ├── integration/       # Integration tests (component interaction)
│   ├── performance/       # Performance tests (benchmarks)
│   ├── stress/            # Stress tests (long-running, edge cases)
│   ├── profile/           # Performance profiling
│   ├── memory/            # Memory analysis
│   ├── benchmarks/        # Legacy benchmark tests
│   └── legacy/            # Legacy tests (for compatibility)
├── examples/               # Usage examples and tutorials
├── tools/                  # Development and utility tools
├── config/                 # Configuration files and templates
├── docs/                   # Documentation
├── scripts/                # Build and installation scripts
├── .github/                # GitHub workflows and templates
├── build.zig              # Build system configuration
├── DEVELOPMENT_WORKFLOW.md # TDD workflow documentation
├── REPOSITORY_ORGANIZATION.md # This file
└── README.md              # Project overview
```

## 🎯 Directory Purposes

### Source Code (`src/`)

The `src/` directory contains all the source code for NenDB:

- **Core Modules**: `graphdb.zig`, `wal.zig`, `memory/`
- **Interface Modules**: `cli/`, `api/`
- **Utility Modules**: `io/`, `query/`, `monitoring/`
- **Entry Points**: `main.zig`, `lib.zig`
- **Configuration**: `constants.zig`

### Test Infrastructure (`tests/`)

The `tests/` directory follows our TDD workflow:

- **Unit Tests** (`unit/`): Fast, isolated tests for individual functions
- **Integration Tests** (`integration/`): Tests for component interactions
- **Performance Tests** (`performance/`): Performance validation and benchmarks
- **Stress Tests** (`stress/`): Long-running tests and edge cases
- **Profile Tools** (`profile/`): Performance profiling utilities
- **Memory Tools** (`memory/`): Memory analysis and leak detection
- **Legacy Tests** (`legacy/`): Maintained for compatibility

### Examples (`examples/`)

The `examples/` directory contains practical examples:

- **Basic Usage**: Simple graph operations and CRUD examples
- **Advanced Features**: Complex graph traversals and optimizations
- **Integration Examples**: API usage and external system integration

### Tools (`tools/`)

The `tools/` directory contains development utilities:

- **Performance Tools**: Built-in profiling and analysis
- **Development Tools**: Code generators and test utilities
- **Maintenance Tools**: Database maintenance and health checks

### Configuration (`config/`)

The `config/` directory contains configuration files:

- **Runtime Config**: Database and performance settings
- **Build Config**: Compile-time options and targets
- **Development Config**: Test and development settings

## 🔧 Build System Integration

The build system (`build.zig`) integrates all components:

```bash
# Run all tests
zig build test-all

# Run specific test categories
zig build test-unit
zig build test-integration
zig build test-performance
zig build test-stress

# Run tools
zig build profile
zig build memory

# Run benchmarks
zig build bench

# Build examples
zig build examples
```

## 📚 Documentation Structure

- **README.md**: Project overview and quick start
- **DEVELOPMENT_WORKFLOW.md**: TDD workflow and coding standards
- **REPOSITORY_ORGANIZATION.md**: This file - repository structure
- **ARCHITECTURE.md**: System architecture and design
- **USABILITY_ROADMAP.md**: Feature roadmap and planning

## 🚀 Development Workflow

### Adding New Features

1. **Create Tests First**: Add tests to appropriate test category
2. **Implement Feature**: Follow NenStyle coding standards
3. **Validate Performance**: Ensure performance targets are met
4. **Update Documentation**: Document new functionality

### Adding New Tests

1. **Choose Test Category**: Unit, integration, performance, or stress
2. **Follow TDD**: Write tests before implementation
3. **Use NenStyle**: Static memory, zero allocation in hot paths
4. **Include Performance**: Add performance assertions where appropriate

### Adding New Tools

1. **Define Purpose**: Clear functionality and use cases
2. **Follow Standards**: Use TDD and NenStyle
3. **Integrate Build**: Add to build system
4. **Document Usage**: Clear instructions and examples

## 🎨 NenStyle Standards

All code follows NenStyle standards:

- **Static Memory**: Use static memory pools for predictable performance
- **Zero Allocation**: No dynamic allocation in hot paths
- **Cache Optimization**: Cache-line aligned data structures
- **Inline Functions**: Critical operations are inline
- **Zero Copy**: Minimize memory copying operations

## 📊 Repository Health

### Current Status

- **Source Code**: ✅ Well organized and documented
- **Test Infrastructure**: ✅ Comprehensive TDD workflow
- **Documentation**: ✅ Clear and comprehensive
- **Build System**: ✅ Integrated and functional
- **Examples**: 🔧 Ready for development
- **Tools**: 🔧 Ready for development
- **Configuration**: 🔧 Ready for development

### Next Steps

1. **Complete Test Migration**: Fix integration and stress tests
2. **Add Examples**: Create practical usage examples
3. **Develop Tools**: Build development utilities
4. **Configuration**: Add configuration file templates

## 🤝 Contributing

When contributing to NenDB:

1. **Follow the Structure**: Use appropriate directories
2. **Follow TDD**: Write tests first
3. **Use NenStyle**: Follow performance coding standards
4. **Update Documentation**: Keep docs current
5. **Test Everything**: Ensure all tests pass

## 📈 Organization Benefits

This organization provides:

- **Clear Separation**: Logical grouping of related functionality
- **Easy Navigation**: Developers can quickly find what they need
- **Scalable Structure**: Easy to add new components
- **Consistent Standards**: All code follows the same patterns
- **Comprehensive Testing**: Full test coverage across all categories
- **Performance Focus**: Built-in performance validation
- **Developer Experience**: Clear workflow and tools
