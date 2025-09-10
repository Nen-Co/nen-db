# NenDB WASM - Embedded Graph Database

A lightweight, high-performance graph database compiled to WebAssembly. Perfect for browser-based applications that need SQLite-like simplicity but for graph data.

## 🚀 Quick Start

### Download Pre-built Files

Download from [GitHub Releases](https://github.com/Nen-Co/nen-db/releases):
- `nendb-wasm.wasm` - The core WASM module (~37KB)
- `nendb-wasm.js` - JavaScript wrapper 
- `example.html` - Working example

### Basic Usage

```html
<!DOCTYPE html>
<html>
<head>
    <title>NenDB WASM Example</title>
</head>
<body>
    <script type="module">
        import NenDB from './nendb-wasm.js';
        
        async function main() {
            // Load the WASM module
            const db = await NenDB.loadFromURL('./nendb-wasm.wasm');
            
            // Add nodes and edges
            const node1 = db.addNode(100);
            const node2 = db.addNode(200);
            const edge = db.addEdge(100, 200, 1.5);
            
            // Check stats
            console.log('Nodes:', db.getNodeCount());
            console.log('Edges:', db.getEdgeCount());
            console.log('Memory usage:', db.getMemoryUsage(), 'bytes');
            
            // Cleanup
            db.destroy();
        }
        
        main().catch(console.error);
    </script>
</body>
</html>
```

### Node.js Usage

```javascript
const fs = require('fs');

async function main() {
    const wasmBytes = fs.readFileSync('./nendb-wasm.wasm');
    const db = await NenDB.create(wasmBytes);
    
    // Use the database
    const nodeId = db.addNode(123);
    console.log('Created node:', nodeId);
    
    db.destroy();
}
```

## ✨ Features

- **🎯 Embedded**: Runs in-process like SQLite, but for graphs
- **⚡ Fast**: Static memory allocation for predictable performance  
- **🪶 Lightweight**: Only ~37KB WASM file
- **🔧 Zero Dependencies**: Pure Zig compiled to clean WASM
- **🌐 Universal**: Works in browsers, Node.js, Deno, Bun
- **🛡️ Type Safe**: Full TypeScript definitions included

## 🏗️ Building from Source

```bash
# Install Zig 0.15.1
curl -L https://ziglang.org/download/0.15.1/zig-linux-x86_64-0.15.1.tar.xz | tar -xJ

# Build WASM
zig build wasm

# Output: zig-out/bin/nendb-wasm.wasm
```

## 📊 Comparison

| Database | WASM Size | Memory Model | Use Case |
|----------|-----------|--------------|----------|
| **NenDB** | **37KB** | **Static pools** | **Graph data, AI/ML** |
| KuzuDB | ~500KB+ | Dynamic allocation | Complex analytics |
| DuckDB | ~2MB+ | Complex memory | SQL analytics |
| SQLite | ~250KB+ | Dynamic allocation | Relational data |

## 🎯 Perfect For

- **Graph visualization** in the browser
- **Social network** analysis
- **Knowledge graphs** and semantic data
- **Embedded AI/ML** applications  
- **Data science** notebooks
- **Progressive Web Apps** with graph data
- **Browser-based** graph databases

## 🔧 API Reference

### Database Operations
- `NenDB.create(wasmBytes)` - Create from WASM bytes
- `NenDB.loadFromURL(wasmUrl)` - Load from URL
- `db.destroy()` - Cleanup resources

### Graph Operations  
- `db.addNode(id)` - Add node, returns index
- `db.addEdge(fromId, toId, weight)` - Add edge
- `db.getNodeCount()` - Number of nodes
- `db.getEdgeCount()` - Number of edges

### Utilities
- `db.getOpsCount()` - Total operations
- `db.getMemoryUsage()` - Memory usage in bytes
- `db.getVersion()` - NenDB version

## 🚧 Current Status

- ✅ Basic graph operations (nodes, edges)
- ✅ Static memory allocation  
- ✅ JavaScript interop
- ✅ Browser and Node.js support
- ⚠️ Pre-v0.1 - APIs may change
- 🔄 Coming: Query language, persistence options

## 📝 License

MIT License - see [LICENSE](../LICENSE) file.

## 🤝 Contributing

See the main [NenDB repository](https://github.com/Nen-Co/nen-db) for contribution guidelines.
