# NenDB 🚀

High-performance graph database with static memory allocation, built in Zig with WebAssembly support.

[![npm version](https://badge.fury.io/js/nendb.svg)](https://www.npmjs.com/package/nendb)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Build Status](https://github.com/Nen-Co/nen-db/workflows/CI/badge.svg)](https://github.com/Nen-Co/nen-db/actions)

## ⚡ Features

- **Zero-allocation runtime**: Static memory pools for predictable performance
- **WASM-powered**: 37KB WebAssembly module for client-side graph processing  
- **Cypher-like queries**: Familiar graph query syntax
- **Crash-safe**: Write-ahead logging (WAL) and snapshot recovery
- **Cross-platform**: Node.js, browsers, and native Zig applications
- **TypeScript support**: Full type definitions included

## 📦 Installation

```bash
# For Node.js applications
npm install nendb

# For browser-only WASM
npm install nendb-wasm
```

## 🚀 Quick Start

### Node.js

```javascript
const { NenDB } = require('nendb');

async function main() {
  const db = new NenDB();
  await db.init();

  // Create nodes
  const aliceId = await db.createNode({ 
    name: 'Alice', 
    age: 30,
    labels: ['Person'] 
  });
  
  const bobId = await db.createNode({ 
    name: 'Bob', 
    age: 25,
    labels: ['Person'] 
  });

  // Create relationship
  await db.createEdge(aliceId, bobId, 'KNOWS', { 
    since: '2023' 
  });

  // Query the graph
  const results = await db.query(`
    MATCH (a:Person)-[:KNOWS]->(b:Person) 
    RETURN a.name, b.name
  `);
  
  console.log(results); // [{ "a.name": "Alice", "b.name": "Bob" }]
  
  await db.close();
}

main().catch(console.error);
```

### ES Modules

```javascript
import { NenDB } from 'nendb';

const db = new NenDB();
await db.init();

const nodeId = await db.createNode({ title: 'Graph Databases', category: 'Technology' });
const results = await db.query('MATCH (n) WHERE n.category = "Technology" RETURN n');
```

### Browser WASM

```html
<script type="module">
  import { NenDBWasm } from 'nendb-wasm';
  
  const db = new NenDBWasm();
  await db.init('/path/to/nendb.wasm');
  
  const nodeId = await db.createNode({ name: 'Client-side Graph' });
  console.log('Node created:', nodeId);
</script>
```

## 📊 Performance

NenDB is designed for high-throughput graph operations:

- **Memory**: Static allocation with configurable pool sizes (64MB-1GB)
- **Disk**: Append-only WAL for crash recovery
- **WASM**: Only 37KB bundle size for browser deployment
- **Queries**: Optimized graph traversal with batch processing

## 🎯 Use Cases

### Real-time Applications
- Social networks and recommendation engines
- Real-time fraud detection
- Knowledge graphs and semantic search

### Client-side Analytics  
- Browser-based data visualization
- Offline-first applications
- Edge computing scenarios

### Microservices
- Embedded graph storage
- Stateful serverless functions
- Container-native deployments

## 📖 API Reference

### `new NenDB(options?)`

Create a new database instance.

**Options:**
- `memorySize?: number` - Memory pool size in bytes (default: 64MB)
- `logLevel?: 'debug' | 'info' | 'warn' | 'error'` - Logging level

### Core Methods

#### `init(): Promise<void>`
Initialize the database and WASM module.

#### `createNode(data: Record<string, any>): Promise<number>`
Create a new node with properties.

#### `createEdge(fromId: number, toId: number, type: string, properties?: Record<string, any>): Promise<number>`
Create a relationship between two nodes.

#### `query(cypherQuery: string): Promise<QueryResult[]>`
Execute a Cypher-like query.

#### `getNode(nodeId: number): Promise<GraphNode | null>`
Retrieve a node by ID.

#### `close(): Promise<void>`
Close the database and free resources.

## 🔍 Query Language

NenDB supports a Cypher-inspired query language:

```cypher
-- Create nodes
CREATE (a:Person {name: 'Alice', age: 30})

-- Match patterns
MATCH (a:Person)-[:KNOWS]->(b:Person) 
WHERE a.age > 25 
RETURN a.name, b.name

-- Aggregations
MATCH (p:Person) 
RETURN count(p) as totalPeople, avg(p.age) as avgAge

-- Path finding
MATCH path = shortestPath((a:Person)-[*]-(b:Person))
WHERE a.name = 'Alice' AND b.name = 'Bob'
RETURN path
```

## 🏗️ Architecture

NenDB is built with the [Nen Way](https://nen.co/docs/architecture) principles:

- **Data-Oriented Design**: Structure-of-arrays for cache efficiency
- **Static Memory**: No runtime allocations after initialization  
- **Batch Processing**: Group operations for maximum throughput
- **Inline Functions**: Aggressive inlining for performance

## 🔧 Development

### Building from Source

```bash
# Clone the repository
git clone https://github.com/Nen-Co/nen-db.git
cd nen-db

# Build WASM module
zig build -Dtarget=wasm32-wasi -Doptimize=ReleaseSmall

# Build JavaScript bindings
npm run build:js

# Run tests
npm test
```

### Requirements

- Zig 0.15.1+
- Node.js 16+
- Modern browser with WASM support

## 📄 License

MIT License - see [LICENSE](LICENSE) for details.

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md).

## 📚 More Resources

- [API Documentation](https://nen.co/docs/nendb/api)
- [Query Language Guide](https://nen.co/docs/nendb/queries)
- [Examples](./EXAMPLES.md)
- [Performance Benchmarks](https://nen.co/docs/nendb/performance)

---

Built with ❤️ by the [Nen.Co](https://nen.co) team
