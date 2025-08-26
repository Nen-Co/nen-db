# NenDB (GraphDB)

Production-focused, static-memory graph store with crash-safe persistence and predictable performance.

[![CI](https://img.shields.io/github/actions/workflow/status/Nen-Co/nendb/ci.yml?branch=main)](../../actions)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)

## Features (production-ready)
- WAL with header/version, CRC per entry, and segment rotation
- Tail scan and auto-truncate of trailing/partial or corrupt bytes
- Atomic snapshots (temp → fsync → rename → dir fsync), length + CRC
- Snapshot .bak fallback on restore
- LSN-aware recovery: restore snapshot, then replay WAL after LSN
- Strict durability (fsync + F_FULLFSYNC on macOS where possible)
- Single-writer safety via lock file next to WAL
- Static memory pools (nodes/edges/embeddings); lock-free reads, mutex-guarded writes
- CLI for init/status/snapshot/restore/check/compact
- Health reporting: WAL health exposed via CLI and API

## Quick install (prebuilt)
Prebuilt binaries are published on GitHub Releases (Linux x86_64, macOS universal, Windows x86_64).

### One-line (Linux/macOS)
```bash
curl -fsSL https://raw.githubusercontent.com/Nen-Co/nendb/main/scripts/install.sh | sh
# Then:
nen status --help
```
This script:
- Detects OS/arch
- Downloads latest release asset + SHA256SUMS
- Verifies checksum
- Places `nen` into `$HOME/.local/bin` (creates if missing)

### Manual download
1. Visit: https://github.com/Nen-Co/nendb/releases
2. Download appropriate archive: `nen-linux-x86_64.tar.gz`, `nen-macos-universal.tar.gz`, or `nen-windows-x86_64.zip`
3. Verify checksum (SHA256SUMS file) and place binary on PATH.

(If the latest release isn’t tagged yet, build from source below.)

## Build from source
```bash
# Build, init a fresh data dir, and start the DB (copy-paste)
zig build -Doptimize=ReleaseSafe && \
    zig-out/bin/nen init ./data && \
    zig-out/bin/nen up ./data
```

Then, in another terminal:

```bash
# Check status (text)
zig-out/bin/nen status ./data

# Or JSON (good for scripts/CI)
zig-out/bin/nen status ./data --json --fail-on-unhealthy
```

Common ops (anytime):

```bash
# Snapshot and restore
zig-out/bin/nen snapshot ./data
zig-out/bin/nen restore ./data

# WAL check (auto-fix trailing partial bytes)
zig-out/bin/nen check ./data

# Compact (snapshot + delete completed segments)
zig-out/bin/nen compact ./data

# Remove stale lock (only if a crash left one behind)
zig-out/bin/nen force-unlock ./data
```

Optional server mode:

```bash
zig-out/bin/nen serve  # listens on :5454
```

No build? Try it right away:

```bash
zig run src/main.zig -- init ./data && zig run src/main.zig -- up ./data
```

Tip: add the build output to your PATH to call `nen` directly:

```bash
export PATH="$PWD/zig-out/bin:$PATH"  # zsh/bash
```

## Install (optional)

User install (recommended, no sudo):

```bash
zig build -Doptimize=ReleaseSafe install-user
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc && exec zsh
```

System install (requires permissions):

```bash
zig build -Doptimize=ReleaseSafe install-system  # may need: sudo zig build ...
```

After install, you can run the CLI anywhere:

```bash
nen status ./data
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
- Restore prefers `nendb.snapshot`; on CRC/length failure, falls back to `nendb.snapshot.bak`; then replays WAL after LSN
- On any CRC mismatch during replay (segments or active), truncates to last good boundary

## Health and operations
- Single-writer lock: `<path>/nendb.wal.lock` ensures one writer per DB path
- Health: `wal_health` includes healthy flag, io_error_count, last_error presence, end_pos, segment stats
- Use `status --fail-on-unhealthy` to integrate with monitors/CI
- Recommended: place `./data` on a local filesystem with fsync durability

## Limitations and expectations
- Single-writer process model (readers are lock-free)
- No replication yet; take regular snapshots and test restores
- Concurrency: writes are mutex-serialized inside the process

## Tests
```bash
# From repository root
zig build test
```
Includes tests for WAL persistence, rotation/replay, tail truncation recovery, snapshot .bak fallback, and single-writer lock.

## Production checklist
- [x] ReleaseSafe or ReleaseFast build
- [x] Single writer per DB path (lock file)
- [x] Local durable filesystem (fsync honored)
- [x] Status checks wired to monitoring (`--fail-on-unhealthy`)
- [x] Snapshot schedule set appropriately (`storage.snapshot_interval`)
- [x] Restore drills validated (snapshot + WAL)

## Benchmarks
The benchmark suite and large benchmark artifacts have been temporarily removed from this repository to keep the v0 release focused and lightweight. If you need performance numbers, open an issue or check the `bench` branch.

## License
Apache-2.0
