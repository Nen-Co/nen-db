# NenDB (GraphDB)

Production-focused, static-memory graph store with crash-safe persistence, predictable performance, and advanced graph algorithms.

[![CI](https://img.shields.io/github/actions/workflow/status/Nen-Co/nendb/ci.yml?branch=main)](../../actions)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)
[![Issues](https://img.shields.io/github/issues/Nen-Co/nendb)](../../issues)
[![Discussions](https://img.shields.io/github/discussions/Nen-Co/nendb)](../../discussions)

> Status: Beta (v0.0.1). Core graph operations and algorithms are functional with production-ready durability features.

## Table of Contents
- [Features (production-ready)](#features-production-ready)
- [Quick install (prebuilt)](#quick-install-prebuilt)
- [Build from source](#build-from-source)
- [Common operations](#common-ops-anytime)
- [Configuration](#configuration)
- [Durability details](#durability-details)
- [Health and operations](#health-and-operations)
- [Limitations and expectations](#limitations-and-expectations)
- [Tests](#tests)
- [Architecture](#architecture)
- [Roadmap](#roadmap)
- [Contributing](#contributing)
- [Benchmarks](#benchmarks)
- [License](#license)

## Features (production-ready)
- **Core Graph Operations**: Node/Edge CRUD, graph traversal, path finding
- **Advanced Graph Algorithms**: BFS, Dijkstra's shortest path, PageRank centrality
- **Graph Analysis Tools**: Connectivity analysis, diameter calculation, path finding, density metrics
- **Enhanced I/O Module**: Static memory, inline functions, UTF-8 support, colored terminal output
- **WAL with header/version**: CRC per entry, and segment rotation
- **Tail scan and auto-truncate**: Trailing/partial or corrupt bytes
- **Atomic snapshots**: Temp → fsync → rename → dir fsync, length + CRC
- **Snapshot .bak fallback**: On restore
- **LSN-aware recovery**: Restore snapshot, then replay WAL after LSN
- **Strict durability**: Fsync + F_FULLFSYNC on macOS where possible
- **Single-writer safety**: Lock file next to WAL
- **Static memory pools**: Nodes/edges/embeddings; lock-free reads, mutex-guarded writes
- **CLI**: Init/status/snapshot/restore/check/compact with enhanced output
- **Health reporting**: WAL health exposed via CLI and API

## Quick install (prebuilt)
Prebuilt binaries are published on GitHub Releases (Linux x86_64, macOS universal, Windows x86_64).

If no release has been tagged yet, skip to [Build from source](#build-from-source).

### One-line (Linux/macOS)
```bash
curl -fsSL https://raw.githubusercontent.com/Nen-Co/nendb/main/scripts/install.sh | sh
# Then:
nendb --help
```
This script:
- Detects OS/arch
- Downloads latest release asset + SHA256SUMS
- Verifies checksum
- Places `nen` into `$HOME/.local/bin` (creates if missing)

### Windows (PowerShell)
```powershell
# Replace VERSION after first release (placeholder using latest tag API):
$uri = Invoke-RestMethod https://api.github.com/repos/Nen-Co/nendb/releases/latest; \
$asset = ($uri.assets | Where-Object { $_.name -like 'nendb-windows-x86_64.zip' }).browser_download_url; \
Invoke-WebRequest $asset -OutFile nendb.zip; Expand-Archive nendb.zip -DestinationPath .; \
Move-Item nendb-windows-x86_64.exe nendb.exe; Write-Host 'Run: ./nendb --help'
```

### Manual download
1. Visit: https://github.com/Nen-Co/nendb/releases
2. Download archive: `nendb-linux-x86_64.tar.gz`, `nendb-macos-universal.tar.gz`, or `nendb-windows-x86_64.zip`
3. Verify checksum (compare against `SHA256SUMS`):
   ```bash
   sha256sum -c SHA256SUMS | grep nendb-linux-x86_64
   ```
4. Put `nendb` on your PATH.

(If the latest release isn’t tagged yet, build from source below.)

## Build from source
```bash
# Build and run demo (copy-paste)
zig build -Doptimize=ReleaseSafe && \
    ./zig-out/bin/nendb demo
```

Try basic operations:

```bash
# Check help
./zig-out/bin/nendb --help

# Run demo
./zig-out/bin/nendb demo
```

## Common ops (anytime):
```bash
# Graph operations demo
./zig-out/bin/nendb demo

# Run algorithms demo
zig build demo

# Basic help
./zig-out/bin/nendb --help

# TODO: Add more operations as implemented
# ./zig-out/bin/nendb snapshot ./data
# ./zig-out/bin/nendb restore ./data
# ./zig-out/bin/nendb check ./data
# ./zig-out/bin/nendb compact ./data
# ./zig-out/bin/nendb force-unlock ./data
```

Optional server mode (TODO):
```bash
./zig-out/bin/nendb serve  # listens on :5454
```

Quick try without a full build:
```bash
zig run src/main.zig -- demo
```

Add build output to PATH:
```bash
export PATH="$PWD/zig-out/bin:$PATH"  # zsh/bash
```

## Install (optional)
User install (no sudo):
```bash
zig build -Doptimize=ReleaseSafe install-user
```
System install:
```bash
zig build -Doptimize=ReleaseSafe install-system  # may need: sudo zig build ...
```

## Configuration
- Compile-time (see `nendb/src/constants.zig`):
  - memory.node_pool_size, edge_pool_size, embedding_pool_size
  - storage.wal_segment_size, storage.snapshot_interval
- Environment overrides:
  - NENDB_SYNC_EVERY (batch fsync interval)
  - NENDB_SEGMENT_SIZE (bytes)

## Durability details
- Appends are O(1) using in-memory tail; correctness from tail-scan on open/rotate
- Rotation fsyncs file and directory before/after rename; header written and fsynced on new active WAL
- Snapshot is atomic (temp file → fsync → rename → dir fsync); then WAL is truncated to header
- Restore prefers `nendb.snapshot`; on CRC/length failure, falls back to `.bak`; then replays WAL after LSN
- On any CRC mismatch during replay (segments or active), truncates to last good boundary

## Health and operations
- Single-writer lock: `<path>/nendb.wal.lock`
- `wal_health` includes healthy flag, io_error_count, last_error, end_pos, segment stats
- Use `status --fail-on-unhealthy` for automation / monitoring hooks

## Limitations and expectations
- Single-writer process model (readers are lock-free)
- No replication yet; rely on snapshots + external backup
- Concurrency: writes serialized by mutex
- Memory sizes fixed at start (static pools)

## Tests
```bash
zig build test
```
Includes tests for WAL persistence, rotation/replay, tail truncation recovery, snapshot .bak fallback, and single-writer lock.

## Architecture
High-level design, lifecycle, and recovery flow: see [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

## Roadmap

### Phase 1: Core Graph Engine (✅ Complete)
- ✅ Static memory pools for nodes, edges, and embeddings
- ✅ WAL persistence with crash-safe recovery
- ✅ Basic graph CRUD operations
- ✅ Core graph algorithms (BFS, Dijkstra, PageRank)
- ✅ Graph analysis utilities (connectivity, diameter, density)
- ✅ Algorithm integration with query executor

### Phase 2: Query Language & Optimization (In Progress)
- 🔄 Cypher-like query language implementation
- 🔄 Query optimization and execution planning
- 🔄 Index structures for performance
- 🔄 Advanced graph traversal patterns
- 🔄 Subgraph operations and filtering

### Phase 3: Advanced Algorithms & Analytics
- 📋 Community detection algorithms
- 📋 Graph clustering and partitioning
- 📋 Centrality measures (betweenness, closeness)
- 📋 Graph embeddings and similarity
- 📋 Machine learning integration

### Phase 4: Production Features
- 📋 Horizontal scaling and sharding
- 📋 Multi-tenant support
- 📋 Advanced monitoring and metrics
- 📋 Backup and disaster recovery
- 📋 Performance benchmarking suite

### Phase 5: AI-Native Features
- 📋 Natural language query interface
- 📋 Automated query optimization
- 📋 Intelligent indexing recommendations
- 📋 Graph pattern learning
- 📋 Predictive analytics

### Long-term Vision
- 📋 Distributed graph processing
- 📋 Real-time streaming graph updates
- 📋 Advanced visualization tools
- 📋 Enterprise security features
- 📋 Cloud-native deployment

## Contributing
1. Fork & clone
2. `zig build test`
3. Make changes + add tests
4. Open PR (auto-templates included)

Looking for first contributions? See issues labeled `good first issue` or propose improvements in Discussions.

## Benchmarks
Benchmarks are gated behind `-Dbench`:
```bash
zig build -Dbench bench
```
(Expect synthetic placeholders; realistic suite in progress. Artifacts removed to keep repo lean.)

## License
Apache-2.0

---
Security / Disclosure: For potential data-loss or integrity issues, please open a private security advisory instead of a public issue.