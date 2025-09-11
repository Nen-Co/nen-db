# NenDB npm + Bun Package

A high-performance graph database compiled to WebAssembly, with both Node.js and Bun runtime optimizations.

## Quick Start

### Node.js Installation
```bash
npm install nendb
# or
npm install nendb-wasm  # WebAssembly only
```

### Bun Installation (Recommended for Performance)
```bash
bun add nendb
```

## Usage

### Node.js
```javascript
// CommonJS
const { NenDB } = require('nendb');

// ES Modules
import { NenDB } from 'nendb';

const db = new NenDB();
await db.init();
```

### Bun (Optimized)
```javascript
import { NenDB } from 'nendb/bun';

const db = new NenDB({
  useFFI: true,      // Enable Bun FFI optimizations
  fastJSON: true,    // Enable Bun's fast JSON parsing
  enableGC: true     // Enable explicit garbage collection
});

await db.init();
```

## Project Templates

Generate new projects with optimized templates:

```bash
# Node.js templates
npx nendb-create basic my-app
npx nendb-create social social-network
npx nendb-create recommendation rec-engine

# Bun-optimized templates (up to 3x faster)
npx nendb-create basic-bun my-bun-app
npx nendb-create social-bun social-network-bun
npx nendb-create recommendation-bun rec-engine-bun
```

## Performance Comparison

| Feature | Node.js | Bun | Improvement |
|---------|---------|-----|-------------|
| JSON Parsing | `JSON.parse()` | `Bun.parseJSON()` | ~2-3x faster |
| WASM Loading | `fs.readFile()` | `Bun.file()` | ~1.5x faster |
| Memory Usage | Standard GC | `Bun.gc(true)` | More predictable |
| Startup Time | Standard | Optimized | ~2x faster |

## Bun-Specific Optimizations

- **Fast JSON**: Uses `Bun.parseJSON()` and `Bun.stringifyJSON()`
- **Optimized WASM Loading**: Uses `Bun.file()` for efficient binary loading  
- **Memory Management**: Explicit garbage collection with `Bun.gc()`
- **High-Precision Timing**: Uses `Bun.nanoseconds()` for benchmarking
- **Batch Operations**: Optimized for Bun's faster array processing

## API Examples

### Basic Operations
```javascript
// Create nodes
const nodeId = await db.createNode({ name: 'Alice', age: 30 });

// Create relationships  
await db.createEdge(alice, bob, 'FRIENDS', { since: 2023 });

// Query with Cypher-like syntax
const results = await db.query(`
  MATCH (a:Person)-[:FRIENDS]-(b:Person)  
  WHERE a.age > 25
  RETURN a.name, b.name
`);
```

### Bun Batch Operations
```javascript
// Batch create (optimized for Bun)
const nodes = await db.createNodesBatch([
  { name: 'Alice', labels: ['Person'] },
  { name: 'Bob', labels: ['Person'] },
  { name: 'Charlie', labels: ['Person'] }
]);

// Batch relationships
await db.createEdgesBatch([
  { from: nodes[0], to: nodes[1], type: 'FRIENDS' },
  { from: nodes[1], to: nodes[2], type: 'FRIENDS' }
]);
```

## Package Details

- **Size**: ~37KB (compressed WASM + JavaScript bindings)
- **Dependencies**: Zero runtime dependencies
- **Compatibility**: Node.js 16+, Bun 1.0+
- **TypeScript**: Full type definitions included
- **Platforms**: macOS (x64/ARM64), Linux (x64/ARM64), Windows (x64)

## Development

```bash
# Install dependencies  
npm install

# Build for Node.js
npm run build

# Build for Bun (includes Node.js)
npm run build:bun  

# Test Node.js
npm test

# Test Bun
npm run test:bun

# Create projects
npm run create basic my-app
npm run create:bun basic-bun my-bun-app
```

## Links

- [GitHub Repository](https://github.com/Nen-Co/nen-db)
- [Documentation](https://nen.co/docs/nendb)
- [API Reference](https://nen.co/docs/nendb/api)
- [Bun Documentation](https://bun.sh/docs)

## License

MIT License - See LICENSE file for details
