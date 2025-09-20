# NenDB Architecture - Data-Oriented Design (DOD)

> **📊 [Current Status →](../CURRENT_STATUS.md)** | **📖 [Roadmap →](../ROADMAP.md)**

## Design Philosophy
NenDB implements **Data-Oriented Design (DOD)** as its core architectural paradigm, prioritizing data layout and memory access patterns over traditional object-oriented abstractions. This approach maximizes performance, cache efficiency, and scalability for graph database operations.

**Note**: This document describes the planned architecture. See [Current Status](../CURRENT_STATUS.md) for what's actually implemented.

## High-Level Components
- **CLI (`nen`)**: entrypoint for admin + ops commands.
- **WAL**: append-only log with segment rotation and CRC validation.
- **Snapshot**: atomic point-in-time state image (LSN + CRC + bak fallback).
- **Recovery**: snapshot restore + WAL replay from stored LSN.
- **DOD Memory Pools**: Struct of Arrays (SoA) layout for nodes, edges, embeddings with hot/cold data separation.
- **Component System**: Entity-Component architecture for flexible graph modeling.
- **SIMD-Optimized Operations**: Vectorized processing for maximum performance.
- **Locking**: single writer mutex; **multi-process support planned but not yet implemented**.
- **Monitoring**: resource monitor (CPU, RSS, IO counters) + `status --json`.

## Write Path (DOD-Optimized)
1. Acquire writer lock.
2. **Batch operations** for better throughput.
3. Serialize entry to pre-allocated buffer (zero-copy).
4. Append to WAL segment (CRC, length).
5. Fsync policy (immediate or batched via env `NENDB_SYNC_EVERY`).
6. **Apply mutations to SoA pools** using vectorized operations.
7. Update component indices atomically.

## Snapshot Lifecycle
1. Quiesce writes (or coordinate point-in-time).
2. Write temp file with header + image.
3. Fsync temp file.
4. Rename to `nendb.snapshot`, fsync directory.
5. Truncate WAL to header, write new segment header.
6. Emit `.bak` of previous snapshot.

## Recovery Sequence
1. If snapshot exists, validate CRC & length; else try `.bak`.
2. Initialize memory pools from snapshot.
3. Sequentially scan WAL segments, validating CRC boundaries.
4. Apply entries after snapshot LSN.
5. On CRC mismatch, truncate to last valid boundary and continue.

## Health Model
- `wal_health` struct: healthy flag, io_error_count, last_error, end_pos, segment stats.
- CLI returns non-zero with `--fail-on-unhealthy` for automation.

## Failure Handling
- Crash during append: tail-scan repairs to last full record.
- Crash during snapshot: `.bak` fallback or previous snapshot + replay.
- Partial segment write: detected via length/CRC mismatch, truncated.

## Concurrency
- **Current**: Single writer process ensures write serialization (same limitation as KùzuDB)
- **Readers**: Operate with read locks on shared memory
- **Limitation**: Cannot handle multiple processes simultaneously
- **Future**: Multi-process support with file locking and shared memory coordination

## Current Limitations
- **Multi-Process**: Cannot handle multiple processes (same as KùzuDB)
- **Distributed**: Framework exists but not implemented
- **Consensus**: No real consensus algorithm
- **Networking**: Basic HTTP server only

## Future Extensions (Not Implemented Yet)
- Multi-process support with file locking
- Real distributed consensus (Raft/PBFT)
- Data replication and synchronization
- Secondary Indexes
- Background compaction scheduling
- Metrics endpoint (HTTP)

## Build Flags
- `-Drelease-safe` / `-Drelease-fast` for optimization.
- `-Dbench` to enable benchmark executables (disabled by default).

## DOD Architecture Diagram
```
+-----------+      +-----------+      +-------------+
|  Client   | ---> |  CLI/IPC  | ---> |  Write Path |
+-----------+      +-----------+      +------+------+ 
                                           |  Apply
                                           v
                    +----------------------+----------------------+
                    |              DOD Memory Pools               |
                    |  +--------+  +--------+  +--------+         |
                    |  | Nodes  |  | Edges  |  |Embeddgs|         |
                    |  | (SoA)  |  | (SoA)  |  | (SoA)  |         |
                    |  +--------+  +--------+  +--------+         |
                    |  +--------+  +--------+  +--------+         |
                    |  |Hot Data|  |Cold Data| |Components|       |
                    |  +--------+  +--------+  +--------+         |
                    +----------------------+----------------------+
                                           | Snapshot
                                           v
+-----------+    Replay    +-----------+   +--------------+
|  WAL Segs | -----------> |  Recovery |-->|  Snapshot(s) |
+-----------+              +-----------+   +--------------+
```

## DOD Benefits
- **Cache Locality**: SoA layout keeps related data together
- **SIMD Optimization**: Vectorized operations on arrays
- **Memory Efficiency**: Hot/cold data separation reduces cache misses
- **Scalability**: Component-based architecture scales with data size
- **Performance**: Predictable memory access patterns

## WebAssembly (WASM) Architecture

NenDB provides a **37KB WASM module** for embedded usage in browsers and JavaScript environments. The WASM build leverages the same DOD architecture but with additional constraints and optimizations for constrained environments.

### WASM-Specific Design
- **Static Memory Pools**: Fixed-size allocation pools defined at compile time
- **Freestanding Target**: No operating system dependencies (`wasm32-freestanding`)
- **C Export Interface**: Simple C-style functions for JavaScript interop
- **Zero Dependencies**: Pure Zig implementation with no external libraries
- **Memory Safety**: Bounds checking and safe memory operations

### WASM Memory Layout
```
+------------------+------------------+------------------+
|   Node Pool      |   Edge Pool      | Component Pool   |
| (SoA Layout)     | (SoA Layout)     | (SoA Layout)     |
+------------------+------------------+------------------+
| Static size      | Static size      | Static size      |
| Cache-friendly   | Vectorized ops   | Hot/cold split   |
+------------------+------------------+------------------+
```

### JavaScript Integration
The WASM module exports C-style functions wrapped by a JavaScript class:
- `nendb_wasm_create()` - Initialize database with static pools
- `nendb_wasm_add_node(id)` - Add node, return index  
- `nendb_wasm_add_edge(from, to, weight)` - Add weighted edge
- `nendb_wasm_destroy()` - Cleanup resources

### Build Process
```bash
# WASM compilation with Zig
zig build-lib src/wasm_lib.zig -target wasm32-freestanding -dynamic -rdynamic
```

### Use Cases
- **Browser Applications**: Client-side graph databases
- **Progressive Web Apps**: Offline graph data storage
- **Edge Computing**: Lightweight graph processing
- **Embedded Systems**: Resource-constrained environments
- **JavaScript Libraries**: Graph utilities for Node.js/Deno/Bun

The WASM architecture maintains NenDB's core DOD principles while adapting to the constraints and opportunities of the WebAssembly runtime environment.

