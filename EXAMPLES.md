# NenDB Examples

## Installation

```bash
npm install nendb
# or for browser-only WASM
npm install nendb-wasm
```

## Node.js Usage

```javascript
const { NenDB } = require('nendb');

async function main() {
  const db = new NenDB();
  await db.init();

  try {
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
    const edgeId = await db.createEdge(aliceId, bobId, 'KNOWS', { 
      since: '2023',
      strength: 0.8 
    });

    // Query the graph
    const results = await db.query(`
      MATCH (a:Person)-[r:KNOWS]->(b:Person) 
      WHERE a.name = 'Alice' 
      RETURN a, r, b
    `);
    
    console.log('Query results:', results);

    // Get specific nodes
    const alice = await db.getNode(aliceId);
    console.log('Alice node:', alice);

  } finally {
    await db.close();
  }
}

main().catch(console.error);
```

## ES Modules Usage

```javascript
import { NenDB } from 'nendb';

const db = new NenDB({
  memorySize: 128 * 1024 * 1024, // 128MB
  logLevel: 'info'
});

await db.init();

// Batch create nodes
const nodes = await Promise.all([
  db.createNode({ name: 'Company A', type: 'organization' }),
  db.createNode({ name: 'Company B', type: 'organization' }),
  db.createNode({ name: 'Product X', type: 'product' })
]);

// Create relationships
await db.createEdge(nodes[0], nodes[2], 'PRODUCES');
await db.createEdge(nodes[1], nodes[2], 'COMPETES_WITH', { intensity: 'high' });
```

## Browser WASM Usage

```html
<!DOCTYPE html>
<html>
<head>
    <title>NenDB WASM Demo</title>
</head>
<body>
    <script type="module">
        import { NenDBWasm } from 'nendb-wasm';
        
        async function runDemo() {
            const db = new NenDBWasm();
            
            // Load WASM from CDN or local file
            await db.init('/path/to/nendb.wasm');
            
            // Create a simple graph
            const node1 = await db.createNode({ name: 'Node 1', value: 42 });
            const node2 = await db.createNode({ name: 'Node 2', value: 24 });
            
            await db.createEdge(node1, node2, 'CONNECTS_TO');
            
            // Query
            const results = await db.query('MATCH (a)-[r]->(b) RETURN a, r, b');
            console.log('Browser query results:', results);
            
            await db.close();
        }
        
        runDemo().catch(console.error);
    </script>
</body>
</html>
```

## Advanced Usage

### Transaction-like Operations

```javascript
import { NenDB } from 'nendb';

const db = new NenDB();
await db.init();

// Simulate a transaction by batching operations
async function createUserWithFriends(userData, friendsData) {
  try {
    // Create user node
    const userId = await db.createNode(userData);
    
    // Create friend nodes and relationships
    const friendIds = [];
    for (const friendData of friendsData) {
      const friendId = await db.createNode(friendData);
      friendIds.push(friendId);
      
      // Create bidirectional friendship
      await db.createEdge(userId, friendId, 'FRIENDS_WITH');
      await db.createEdge(friendId, userId, 'FRIENDS_WITH');
    }
    
    return { userId, friendIds };
  } catch (error) {
    console.error('Operation failed:', error);
    throw error;
  }
}

// Usage
const result = await createUserWithFriends(
  { name: 'John', age: 28, city: 'New York' },
  [
    { name: 'Jane', age: 26, city: 'Boston' },
    { name: 'Mike', age: 30, city: 'Chicago' }
  ]
);
```

### Complex Queries

```javascript
// Find mutual friends
const mutualFriends = await db.query(`
  MATCH (a:Person)-[:FRIENDS_WITH]->(mutual:Person)<-[:FRIENDS_WITH]-(b:Person)
  WHERE a.name = 'John' AND b.name = 'Jane'
  RETURN mutual
`);

// Find shortest path
const shortestPath = await db.query(`
  MATCH path = shortestPath((start:Person)-[*]-(end:Person))
  WHERE start.name = 'Alice' AND end.name = 'Bob'
  RETURN path, length(path) as distance
`);

// Aggregation queries
const stats = await db.query(`
  MATCH (p:Person)
  RETURN 
    count(p) as totalPeople,
    avg(p.age) as averageAge,
    min(p.age) as youngestAge,
    max(p.age) as oldestAge
`);
```

### Performance Tips

1. **Batch Operations**: Group multiple operations when possible
2. **Memory Management**: Set appropriate memory limits based on your data size
3. **Query Optimization**: Use indexes and limit result sets
4. **Connection Pooling**: Reuse database instances when possible

```javascript
// Good: Batch node creation
const nodeData = [
  { name: 'A', value: 1 },
  { name: 'B', value: 2 },
  { name: 'C', value: 3 }
];

const nodeIds = await Promise.all(
  nodeData.map(data => db.createNode(data))
);

// Good: Efficient querying
const results = await db.query(`
  MATCH (n:Person) 
  WHERE n.age > 25 
  RETURN n 
  LIMIT 100
`);
```
