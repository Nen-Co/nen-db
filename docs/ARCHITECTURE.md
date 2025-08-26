# NenDB Architecture (Draft)

## High-Level Components
- CLI (`nen`): entrypoint for admin + ops commands.
- WAL: append-only log with segment rotation and CRC validation.
- Snapshot: atomic point-in-time state image (LSN + CRC + bak fallback).
- Recovery: snapshot restore + WAL replay from stored LSN.
- Memory Pools: fixed arrays for nodes, edges, embeddings (predictable footprint, lock-free reads).
- Locking: single writer mutex; per-writer lock file to prevent multi-process writers.
- Monitoring: resource monitor (CPU, RSS, IO counters) + `status --json`.

## Write Path
1. Acquire writer lock.
2. Serialize entry to in-memory buffer.
3. Append to WAL segment (CRC, length).
4. Fsync policy (immediate or batched via env `NENDB_SYNC_EVERY`).
5. Apply mutation to in-memory pools.

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

## Diagram (simplified)
```
+-----------+      +-----------+      +-------------+
|  Client   | ---> |  CLI/IPC  | ---> |  Write Path |
+-----------+      +-----------+      +------+------+ 
                                           |  Apply
                                           v
                                      +----+-----+
                                      |  Memory  |
                                      |  Pools   |
                                      +----+-----+
                                           | Snapshot
                                           v
+-----------+    Replay    +-----------+   +--------------+
|  WAL Segs | -----------> |  Recovery |-->|  Snapshot(s) |
+-----------+              +-----------+   +--------------+
```

