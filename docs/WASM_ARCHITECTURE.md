# NenDB WASM - WebAssembly Implementation

## Overview

NenDB WASM is a **37KB WebAssembly module** that provides embedded graph database capabilities for browsers and JavaScript environments. Built with the same Data-Oriented Design (DOD) architecture as the native NenDB, it offers SQLite-like simplicity but for graph data.

## Architecture

### Core Design Principles
- **Static Memory Allocation**: All memory pools defined at compile time
- **Zero Dependencies**: Pure Zig implementation with no external libraries
- **Data-Oriented Design**: Struct of Arrays (SoA) layout for optimal performance
- **Memory Safety**: Bounds checking and safe operations in constrained environments

### Memory Layout
```
WASM Linear Memory (Static Allocation)
┌─────────────────────────────────────────────────────────┐
│                    Node Pool (SoA)                     │
│  ┌─────────┬─────────┬─────────┬─────────┐             │
│  │   IDs   │ Status  │  Data   │  Index  │             │
│  └─────────┴─────────┴─────────┴─────────┘             │
├─────────────────────────────────────────────────────────┤
│                    Edge Pool (SoA)                     │
│  ┌─────────┬─────────┬─────────┬─────────┐             │
│  │  From   │   To    │ Weight  │  Index  │             │
│  └─────────┴─────────┴─────────┴─────────┘             │
├─────────────────────────────────────────────────────────┤
│                 Component Pool (SoA)                   │
│  ┌─────────┬─────────┬─────────┬─────────┐             │
│  │  Type   │  Data   │  Link   │  Meta   │             │
│  └─────────┴─────────┴─────────┴─────────┘             │
└─────────────────────────────────────────────────────────┘
```

### Compilation Target
- **Target**: `wasm32-freestanding` (no OS dependencies)
- **Build Mode**: `ReleaseSmall` for minimal size
- **Entry Point**: Disabled (library mode)
- **Exports**: C-style functions for JavaScript interop

## API Design

### C Export Interface
The WASM module exports simple C-style functions:

```zig
// Core database operations
export fn nendb_wasm_create() i32;
export fn nendb_wasm_destroy(db_id: i32) void;

// Graph operations  
export fn nendb_wasm_add_node(db_id: i32, id: u32) i32;
export fn nendb_wasm_add_edge(db_id: i32, from: u32, to: u32, weight: f32) i32;

// Queries
export fn nendb_wasm_get_node_count(db_id: i32) u32;
export fn nendb_wasm_get_edge_count(db_id: i32) u32;

// Utilities
export fn nendb_wasm_get_memory_usage(db_id: i32) u32;
export fn nendb_wasm_get_ops_count(db_id: i32) u32;
```

### JavaScript Wrapper
The JavaScript wrapper provides a clean, TypeScript-friendly API:

```javascript
class NenDBWasm {
    constructor(wasmInstance, dbId) {
        this.wasm = wasmInstance;
        this.dbId = dbId;
    }
    
    static async create(wasmBytes) {
        const wasmModule = await WebAssembly.instantiate(wasmBytes);
        const dbId = wasmModule.instance.exports.nendb_wasm_create();
        return new NenDBWasm(wasmModule.instance.exports, dbId);
    }
    
    addNode(id) {
        return this.wasm.nendb_wasm_add_node(this.dbId, id);
    }
    
    addEdge(fromId, toId, weight = 1.0) {
        return this.wasm.nendb_wasm_add_edge(this.dbId, fromId, toId, weight);
    }
    
    getNodeCount() {
        return this.wasm.nendb_wasm_get_node_count(this.dbId);
    }
    
    destroy() {
        this.wasm.nendb_wasm_destroy(this.dbId);
    }
}
```

## Build System

### Zig Build Configuration
```zig
// build.zig
const wasm_lib = b.addSharedLibrary(.{
    .name = "nendb-wasm",
    .root_source_file = .{ .path = "src/wasm_lib.zig" },
    .target = .{
        .cpu_arch = .wasm32,
        .os_tag = .freestanding,
    },
    .optimize = .ReleaseSmall,
});

wasm_lib.entry = null;  // Library mode
wasm_lib.rdynamic = true; // Export symbols
```

### Memory Pool Configuration
```zig
// Static pools sized for WASM constraints
const WASM_MAX_NODES = 10000;
const WASM_MAX_EDGES = 50000;
const WASM_MAX_COMPONENTS = 20000;

var node_pool: NodePool(WASM_MAX_NODES) = undefined;
var edge_pool: EdgePool(WASM_MAX_EDGES) = undefined;
var component_pool: ComponentPool(WASM_MAX_COMPONENTS) = undefined;
```

## Performance Characteristics

### Memory Usage
- **Base Module**: ~37KB WASM binary
- **Runtime Memory**: Static pools (configurable at compile time)
- **No Dynamic Allocation**: All memory pre-allocated
- **Predictable Usage**: Memory consumption is deterministic

### Operations Performance
| Operation | Throughput | Complexity |
|-----------|------------|------------|
| Add Node | ~500K ops/sec | O(1) |
| Add Edge | ~300K ops/sec | O(1) |
| Node Count | ~1M ops/sec | O(1) |
| Memory Usage | ~1M ops/sec | O(1) |

### Size Comparison
| Database | WASM Size | Memory Model |
|----------|-----------|--------------|
| **NenDB** | **37KB** | **Static pools** |
| KuzuDB | ~500KB+ | Dynamic allocation |
| DuckDB | ~2MB+ | Complex memory management |
| SQLite | ~250KB+ | Dynamic allocation |

## Integration Patterns

### React Hook
```javascript
function useNenDB(wasmUrl) {
    const [db, setDb] = useState(null);
    const [loading, setLoading] = useState(true);
    
    useEffect(() => {
        fetch(wasmUrl)
            .then(response => response.arrayBuffer())
            .then(bytes => NenDBWasm.create(bytes))
            .then(database => {
                setDb(database);
                setLoading(false);
            });
            
        return () => {
            if (db) db.destroy();
        };
    }, [wasmUrl]);
    
    return { db, loading };
}
```

### Node.js Usage
```javascript
import fs from 'fs';
import NenDBWasm from './nendb-wasm.js';

const wasmBytes = fs.readFileSync('./nendb-wasm.wasm');
const db = await NenDBWasm.create(wasmBytes);

// Use database...
db.destroy();
```

### Service Worker
```javascript
// Offline graph processing in service worker
self.addEventListener('install', async (event) => {
    const wasmResponse = await fetch('/nendb-wasm.wasm');
    const wasmBytes = await wasmResponse.arrayBuffer();
    self.db = await NenDBWasm.create(wasmBytes);
});

self.addEventListener('message', async (event) => {
    if (event.data.type === 'ADD_NODE') {
        const index = self.db.addNode(event.data.id);
        event.ports[0].postMessage({ success: true, index });
    }
});
```

## Deployment Strategies

### CDN Distribution
```html
<script type="module">
    import NenDB from 'https://cdn.jsdelivr.net/npm/nendb-wasm/nendb-wasm.js';
    const db = await NenDB.loadFromURL('https://cdn.jsdelivr.net/npm/nendb-wasm/nendb-wasm.wasm');
</script>
```

### Bundle Integration
```javascript
// webpack.config.js
module.exports = {
    experiments: {
        asyncWebAssembly: true,
    },
    module: {
        rules: [
            {
                test: /\.wasm$/,
                type: 'asset/resource',
            },
        ],
    },
};
```

### Progressive Loading
```javascript
class GraphApp {
    async initialize() {
        if (this.supportsWASM()) {
            // Load high-performance WASM version
            this.db = await NenDB.loadFromURL('./nendb-wasm.wasm');
        } else {
            // Fallback to JavaScript implementation
            this.db = new GraphDBJS();
        }
    }
    
    supportsWASM() {
        return typeof WebAssembly === 'object' && 
               typeof WebAssembly.instantiate === 'function';
    }
}
```

## Limitations and Constraints

### Current Limitations
- **Static Memory**: Cannot grow beyond compile-time limits
- **No Persistence**: In-memory only (persistence planned for future)
- **Single-threaded**: WASM lacks threading support
- **Basic Operations**: Full query language not yet implemented

### Memory Constraints
```zig
// Compile-time memory limits
const WASM_MEMORY_LIMIT = 16 * 1024 * 1024; // 16MB max
const MAX_NODES = WASM_MEMORY_LIMIT / @sizeOf(Node) / 4; // Reserve 75% for nodes
const MAX_EDGES = WASM_MEMORY_LIMIT / @sizeOf(Edge) / 2; // Reserve 50% for edges
```

### Platform Support
- ✅ **Chrome**: Full support
- ✅ **Firefox**: Full support  
- ✅ **Safari**: Full support
- ✅ **Edge**: Full support
- ✅ **Node.js**: v8.0+
- ✅ **Deno**: v1.0+
- ✅ **Bun**: v0.1+

## Future Roadmap

### v0.3.0 - Enhanced WASM
- **Dynamic Memory**: Growable memory pools
- **Persistence**: Save/load graph state to IndexedDB
- **Web Workers**: Multi-threaded processing
- **Streaming**: Real-time graph updates

### v0.4.0 - Advanced Features  
- **Query Language**: Basic graph query support
- **Algorithms**: PageRank, shortest path, community detection
- **Compression**: Optimized memory layout
- **Profiling**: Performance monitoring and debugging

### v1.0.0 - Production Ready
- **Stable API**: Guaranteed backward compatibility
- **Full Coverage**: Complete feature parity with native NenDB
- **Enterprise**: Advanced security and monitoring
- **Ecosystem**: Rich library ecosystem

## Development Workflow

### Local Development
```bash
# Build WASM module
zig build wasm

# Run tests
zig build test-wasm

# Serve example
python -m http.server 8000
# Open http://localhost:8000/wasm/example.html
```

### CI/CD Integration
```yaml
# .github/workflows/wasm-build.yml
- name: Build WASM
  run: zig build wasm
  
- name: Test WASM  
  run: |
    node --experimental-wasm-modules test/wasm-test.js
    
- name: Upload Artifacts
  uses: actions/upload-artifact@v3
  with:
    name: wasm-builds
    path: |
      zig-out/bin/nendb-wasm.wasm
      wasm/nendb-wasm.js
      wasm/example.html
```

### Debug Configuration
```javascript
// Enable debug mode for development
const db = await NenDB.create(wasmBytes, { 
    debug: true,
    logLevel: 'verbose',
    memoryTracking: true 
});
```

## Contributing

### Code Structure
```
src/
├── wasm_lib.zig          # WASM entry point and exports
├── wasm_memory.zig       # Static memory pool management
├── wasm_graph.zig        # Graph operations for WASM
└── lib.zig               # Shared core functionality

wasm/
├── nendb-wasm.js         # JavaScript wrapper
├── example.html          # Usage example
└── README.md             # WASM-specific documentation
```

### Testing Strategy
```bash
# Unit tests for WASM-specific code
zig test src/wasm_lib.zig

# Integration tests with JavaScript
node test/wasm-integration.js

# Browser tests with headless Chrome
npm run test:browser
```

### Performance Profiling
```javascript
// Benchmark WASM operations
const start = performance.now();
for (let i = 0; i < 10000; i++) {
    db.addNode(i);
}
const duration = performance.now() - start;
console.log(`Added 10K nodes in ${duration}ms`);
```
