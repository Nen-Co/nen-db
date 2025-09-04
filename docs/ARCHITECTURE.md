# NenDB Architecture - Data-Oriented Design (DOD)

## Design Philosophy
NenDB implements **Data-Oriented Design (DOD)** as its core architectural paradigm, prioritizing data layout and memory access patterns over traditional object-oriented abstractions. This approach maximizes performance, cache efficiency, and scalability for graph database operations.

## High-Level Components
- **CLI (`nen`)**: entrypoint for admin + ops commands.
- **WAL**: append-only log with segment rotation and CRC validation.
- **Snapshot**: atomic point-in-time state image (LSN + CRC + bak fallback).
- **Recovery**: snapshot restore + WAL replay from stored LSN.
- **DOD Memory Pools**: Struct of Arrays (SoA) layout for nodes, edges, embeddings with hot/cold data separation.
- **Component System**: Entity-Component architecture for flexible graph modeling.
- **SIMD-Optimized Operations**: Vectorized processing for maximum performance.
- **Locking**: single writer mutex; per-writer lock file to prevent multi-process writers.
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
- Single writer process ensures write serialization.
- Readers operate lock-free on immutable memory segments / atomically swapped pointers.

## Future Extensions (Not Implemented Yet)
- Replication (log shipping)
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

