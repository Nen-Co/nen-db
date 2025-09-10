# NenDB Project Structure

## 📁 Directory Organization

### Core Source Code
```
src/
├── algorithms/          # Graph algorithms (SSSP, etc.)
├── api/                # API layer for external interfaces
├── batch/              # Batch processing for DOD architecture  
├── cli/                # Command-line interface components
├── data_types/         # Core data structures and types
├── document_processing/ # Document handling and processing
├── memory/             # Memory management and pools
├── monitoring/         # Performance and resource monitoring
├── query/              # Query processing engine
├── constants.zig       # System-wide constants
├── graphdb.zig         # Main graph database implementation
├── lib.zig             # Library interface
├── main.zig            # Main CLI executable
├── server_main.zig     # HTTP server entry point
├── tcp_server_main.zig # High-performance TCP server
└── wal.zig            # Write-Ahead Log implementation
```

### Testing Suite
```
tests/
├── algorithms/         # Algorithm-specific tests
├── benchmarks/         # Performance benchmarks
├── integration/        # Full system integration tests
├── memory/            # Memory management tests
├── performance/       # Performance regression tests
├── profile/           # Performance profiling tools
├── stress/            # Stress testing scenarios
├── tcp/               # TCP server tests
└── unit/              # Unit tests for individual components
```

### Documentation
```
docs/
├── deployment/        # Docker, contributing, security
│   ├── CODE_OF_CONDUCT.md
│   ├── CONTRIBUTING.md
│   ├── DOCKER.md
│   ├── Dockerfile
│   ├── Dockerfile.simple
│   └── SECURITY.md
├── development/       # Development guides and roadmaps
│   ├── CHANGELOG.md
│   ├── CLEANUP_REPORT.md
│   ├── ECOSYSTEM_CLEANUP_REPORT.md
│   ├── REPOSITORY_ORGANIZATION.md
│   ├── RESOURCE_MONITORING_FEATURE.md
│   ├── SSSP_ALGORITHM_IMPLEMENTATION.md
│   └── USABILITY_ROADMAP.md
└── reference/         # Reference documentation
    └── openCypher9.pdf
```

### Build System & Configuration
```
config/                # Configuration files
examples/              # Example usage and demos
scripts/               # Build and deployment scripts  
tools/                 # Development tools and utilities
archive/               # Legacy code kept for reference
  └── legacy/          # Old Cypher parser tests
build.zig              # Main build configuration
```

## 🧹 Cleanup Changes Made

### ✅ Removed Clutter
- **Build artifacts**: `test`, `test_anyerror`, `test_stdout`, `batch_processor`
- **Runtime files**: `nendb.wal` (now properly gitignored)  
- **Temporary files**: `test_anyerror.zig`

### ✅ Organized Documentation  
- **Deployment docs**: Moved Docker, contributing, security to `docs/deployment/`
- **Development docs**: Moved changelogs, reports, roadmaps to `docs/development/`
- **Reference docs**: Moved openCypher PDF to `docs/reference/`

### ✅ Archived Legacy Code
- **Legacy tests**: Moved old Cypher parser tests to `archive/legacy/`
- **Reason**: No longer relevant with TCP + DOD architecture

### ✅ Enhanced .gitignore
- **Build artifacts**: Prevent executables from cluttering root
- **Runtime files**: Better WAL and data file handling

## 📊 Results

**Before**: 26+ files in root directory  
**After**: 7 essential files in root directory

**Root Directory Now Contains Only:**
- `.gitignore`, `.gitmodules` (Git configuration)
- `build.zig` (Build system)
- `CODEOWNERS` (GitHub configuration)  
- `LICENSE` (Legal)
- `README.md`, `README.release.md` (Documentation)

Much cleaner and more professional! 🚀
