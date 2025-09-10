# Getting Started with NenDB

## Quick Installation

```bash
# For Node.js projects
npm install nendb

# For browser-only WebAssembly
npm install nendb-wasm
```

## Your First Graph

### Node.js Example

Create a file called `example.js`:

```javascript
const { NenDB } = require('nendb');

async function createSocialGraph() {
  // Initialize database
  const db = new NenDB();
  await db.init();

  try {
    console.log('🚀 Creating a social network graph...');

    // Create people
    const alice = await db.createNode({ 
      name: 'Alice', 
      age: 28, 
      city: 'San Francisco',
      labels: ['Person'] 
    });

    const bob = await db.createNode({ 
      name: 'Bob', 
      age: 32, 
      city: 'New York',
      labels: ['Person'] 
    });

    const charlie = await db.createNode({ 
      name: 'Charlie', 
      age: 25, 
      city: 'Austin',
      labels: ['Person'] 
    });

    // Create relationships
    await db.createEdge(alice, bob, 'KNOWS', { 
      since: '2020',
      strength: 0.8 
    });

    await db.createEdge(bob, charlie, 'WORKS_WITH', { 
      company: 'Tech Corp',
      department: 'Engineering' 
    });

    await db.createEdge(alice, charlie, 'FRIENDS', { 
      since: '2019',
      closeness: 'close' 
    });

    console.log('✅ Graph created successfully!');

    // Query the network
    console.log('\n🔍 Finding Alice\'s connections...');
    
    const connections = await db.query(`
      MATCH (alice:Person)-[r]-(connected:Person)
      WHERE alice.name = 'Alice'
      RETURN alice.name as person, 
             connected.name as connection, 
             type(r) as relationship
    `);

    console.log('Alice\'s network:', connections);

    // Find mutual connections
    console.log('\n🕸️  Finding mutual friends...');
    
    const mutuals = await db.query(`
      MATCH (a:Person)-[:KNOWS|FRIENDS]-(mutual:Person)-[:KNOWS|FRIENDS|WORKS_WITH]-(b:Person)
      WHERE a.name = 'Alice' AND b.name = 'Charlie'
      RETURN DISTINCT mutual.name as mutual_friend
    `);

    console.log('Mutual connections:', mutuals);

  } finally {
    await db.close();
  }
}

// Run the example
createSocialGraph().catch(console.error);
```

Run it:

```bash
node example.js
```

### Browser Example

Create an HTML file:

```html
<!DOCTYPE html>
<html>
<head>
    <title>NenDB Browser Demo</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .result { background: #f5f5f5; padding: 10px; margin: 10px 0; }
        button { padding: 10px 20px; margin: 5px; cursor: pointer; }
    </style>
</head>
<body>
    <h1>🚀 NenDB in the Browser</h1>
    <button onclick="runDemo()">Create Graph Database</button>
    <div id="results"></div>

    <script type="module">
        import { NenDBWasm } from './node_modules/nendb-wasm/dist/nendb-wasm.js';

        window.runDemo = async function() {
            const resultsDiv = document.getElementById('results');
            resultsDiv.innerHTML = '<p>⏳ Initializing database...</p>';

            try {
                const db = new NenDBWasm();
                
                // Load WASM module
                await db.init('./node_modules/nendb-wasm/dist/nendb.wasm');
                
                resultsDiv.innerHTML += '<p>✅ Database initialized</p>';

                // Create nodes
                const user1 = await db.createNode({ 
                    name: 'Web User', 
                    browser: 'Chrome',
                    type: 'visitor' 
                });
                
                const page1 = await db.createNode({ 
                    title: 'Homepage', 
                    url: '/home',
                    type: 'page' 
                });

                // Create relationship
                await db.createEdge(user1, page1, 'VISITED', { 
                    timestamp: new Date().toISOString(),
                    duration: 45 
                });

                resultsDiv.innerHTML += '<p>✅ Graph data created</p>';

                // Query the graph
                const visits = await db.query(`
                    MATCH (user)-[visit:VISITED]->(page)
                    RETURN user.name, page.title, visit.duration
                `);

                resultsDiv.innerHTML += `
                    <div class="result">
                        <h3>Query Results:</h3>
                        <pre>${JSON.stringify(visits, null, 2)}</pre>
                    </div>
                `;

                await db.close();

            } catch (error) {
                resultsDiv.innerHTML += `<p>❌ Error: ${error.message}</p>`;
            }
        };
    </script>
</body>
</html>
```

## Common Patterns

### 1. Recommendation Engine

```javascript
const { NenDB } = require('nendb');

async function buildRecommendationGraph() {
  const db = new NenDB();
  await db.init();

  // Users and their preferences
  const alice = await db.createNode({ name: 'Alice', labels: ['User'] });
  const movie1 = await db.createNode({ title: 'Inception', genre: 'Sci-Fi', labels: ['Movie'] });
  const movie2 = await db.createNode({ title: 'The Matrix', genre: 'Sci-Fi', labels: ['Movie'] });

  // User interactions
  await db.createEdge(alice, movie1, 'WATCHED', { rating: 5, date: '2023-01-15' });
  await db.createEdge(alice, movie2, 'WATCHED', { rating: 4, date: '2023-02-01' });

  // Find similar movies
  const recommendations = await db.query(`
    MATCH (user:User)-[:WATCHED]->(watched:Movie)
    MATCH (watched)-[:SIMILAR_TO]-(similar:Movie)
    WHERE user.name = 'Alice' 
      AND NOT (user)-[:WATCHED]->(similar)
    RETURN similar.title, similar.genre
    ORDER BY similar.rating DESC
    LIMIT 5
  `);

  await db.close();
  return recommendations;
}
```

### 2. Knowledge Graph

```javascript
async function buildKnowledgeGraph() {
  const db = new NenDB();
  await db.init();

  // Entities
  const python = await db.createNode({ name: 'Python', type: 'language', labels: ['Programming'] });
  const django = await db.createNode({ name: 'Django', type: 'framework', labels: ['Web'] });
  const postgres = await db.createNode({ name: 'PostgreSQL', type: 'database', labels: ['Storage'] });

  // Relationships
  await db.createEdge(django, python, 'BUILT_WITH');
  await db.createEdge(django, postgres, 'SUPPORTS');

  // Semantic queries
  const techStack = await db.query(`
    MATCH (framework:Web)-[:BUILT_WITH]->(lang:Programming)
    MATCH (framework)-[:SUPPORTS]->(db:Storage)
    RETURN framework.name, lang.name, db.name
  `);

  await db.close();
  return techStack;
}
```

### 3. Social Network Analysis

```javascript
async function analyzeSocialNetwork() {
  const db = new NenDB();
  await db.init();

  // Create a larger network...
  // (nodes and edges creation)

  // Find influencers (high degree centrality)
  const influencers = await db.query(`
    MATCH (person:Person)-[r]-(connected)
    WITH person, count(r) as connections
    WHERE connections > 10
    RETURN person.name, connections
    ORDER BY connections DESC
    LIMIT 5
  `);

  // Find communities (strongly connected components)
  const communities = await db.query(`
    MATCH (a:Person)-[:FRIENDS*2..3]-(b:Person)
    WHERE a.name < b.name
    RETURN a.name, b.name, 
           length(shortestPath((a)-[:FRIENDS*]-(b))) as distance
    ORDER BY distance
  `);

  await db.close();
  return { influencers, communities };
}
```

## Performance Tips

### Memory Management
```javascript
const db = new NenDB({
  memorySize: 256 * 1024 * 1024, // 256MB for large datasets
  logLevel: 'warn' // Reduce logging overhead
});
```

### Batch Operations
```javascript
// Efficient: Batch create nodes
const userData = [
  { name: 'User1', age: 25 },
  { name: 'User2', age: 30 },
  { name: 'User3', age: 35 }
];

const nodeIds = await Promise.all(
  userData.map(data => db.createNode(data))
);

// Then create relationships
await Promise.all([
  db.createEdge(nodeIds[0], nodeIds[1], 'KNOWS'),
  db.createEdge(nodeIds[1], nodeIds[2], 'KNOWS')
]);
```

### Query Optimization
```javascript
// Good: Use specific node types and limit results
const results = await db.query(`
  MATCH (p:Person)-[:WORKS_AT]->(c:Company)
  WHERE c.name = 'TechCorp'
  RETURN p.name, p.role
  LIMIT 100
`);

// Good: Use indexes when available
const indexed = await db.query(`
  MATCH (p:Person {email: 'user@example.com'})
  RETURN p
`);
```

## Next Steps

1. **Read the [API Documentation](https://nen.co/docs/nendb/api)**
2. **Explore [Advanced Examples](./EXAMPLES.md)**
3. **Check [Performance Benchmarks](https://nen.co/docs/nendb/performance)**
4. **Join the [Community](https://nen.co/docs/community)**

## Need Help?

- 📖 [Full Documentation](https://nen.co/docs/nendb)
- 💬 [GitHub Discussions](https://github.com/Nen-Co/nen-db/discussions)
- 🐛 [Report Issues](https://github.com/Nen-Co/nen-db/issues)
- 🌟 [Star on GitHub](https://github.com/Nen-Co/nen-db)
