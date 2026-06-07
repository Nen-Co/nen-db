# Troubleshooting

This guide lists common NenDB errors, what they usually mean, and the first checks to run. Examples use local development defaults and mock values only.

## Connection errors

### `Connection refused` or `Cannot connect to server`

The client cannot reach the NenDB HTTP server.

1. Start the server with the documented command, such as `zig build run`.
2. Confirm the client URL uses the default local address: `http://localhost:8080`.
3. Check the health endpoint from another terminal:

   ```bash
   curl http://localhost:8080/health
   ```

4. If you run NenDB in Docker, confirm the port is published with `-p 8080:8080`.

### `Address already in use` or port `8080` is busy

Another process is already listening on the default NenDB port.

1. Stop the previous NenDB process or container.
2. Check whether a container is still running with `docker ps`.
3. Start NenDB again and retry `curl http://localhost:8080/health`.

## Graph operation errors

### `NodeNotFound`

A graph operation referenced a node id that is not present in the current graph.

1. Confirm the node was inserted before adding edges or running algorithms.
2. Check for typos or id mismatches in your sample data.
3. Re-run a small graph first, then scale up once the ids are correct.

### `InvalidEdge`

An edge references missing nodes or uses invalid edge data.

1. Verify both source and target nodes exist.
2. Confirm edge weights and labels match the API or example you are following.
3. Reduce the operation to one edge and add more edges only after the minimal case works.

## Memory and performance errors

### `OutOfMemory`

The graph or query needs more memory than the current local configuration can provide.

1. Try a smaller dataset to confirm the workflow is correct.
2. Avoid loading large generated datasets during a first local smoke test.
3. Review memory-pool or dataset-size settings before increasing workload size.

### Timeout or very slow response

The workload may be too large for the current local run, or the server may still be starting.

1. Retry the health check before running a larger graph operation.
2. Test with the smallest example graph or Python client snippet first.
3. Capture the command, dataset size, and platform when opening an issue.

## Build and compilation errors

### Zig version mismatch

NenDB currently documents Zig `0.15.1` in the README badge.

1. Check your local version:

   ```bash
   zig version
   ```

2. Install a compatible Zig version from the official Zig download page.
3. Re-run `zig build` after updating your PATH.

### Missing dependency or command not found

Required tools such as `zig`, `python`, `docker`, or `curl` may be missing from PATH.

1. Run the command with `--version` when available, for example `zig version` or `python --version`.
2. Install the missing tool for your operating system.
3. Open a new terminal so PATH changes are loaded, then retry the build or smoke test.
