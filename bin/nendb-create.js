#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

const templates = {
  'basic': `const { NenDB } = require('nendb');

async function main() {
  const db = new NenDB();
  await db.init();

  try {
    // Create your first node
    const nodeId = await db.createNode({ 
      name: 'My First Node', 
      created: new Date().toISOString() 
    });
    
    console.log('Created node with ID:', nodeId);
    
    // Query it back
    const node = await db.getNode(nodeId);
    console.log('Retrieved node:', node);
    
  } finally {
    await db.close();
  }
}

main().catch(console.error);`,

  'basic-bun': `import { NenDB } from 'nendb/bun';

const db = new NenDB({
  useFFI: true,      // Enable Bun FFI optimizations
  fastJSON: true     // Enable Bun's fast JSON
});

await db.init();

try {
  // Create your first node (Bun optimized)
  const nodeId = await db.createNode({ 
    name: 'My First Bun Node', 
    created: new Date().toISOString(),
    runtime: 'Bun'
  });
  
  console.log('Created node with ID:', nodeId);
  
  // Query it back with Bun's fast JSON parsing
  const node = await db.getNode(nodeId);
  console.log('Retrieved node:', node);
  
} finally {
  await db.close();
}`,

  'social': `const { NenDB } = require('nendb');

async function buildSocialNetwork() {
  const db = new NenDB();
  await db.init();

  try {
    // Create people
    const alice = await db.createNode({ name: 'Alice', age: 28, labels: ['Person'] });
    const bob = await db.createNode({ name: 'Bob', age: 32, labels: ['Person'] });
    
    // Create friendship
    await db.createEdge(alice, bob, 'FRIENDS', { since: '2023' });
    
    // Query the network
    const friends = await db.query(\`
      MATCH (a:Person)-[:FRIENDS]-(b:Person)
      RETURN a.name, b.name
    \`);
    
    console.log('Friends found:', friends);
    
  } finally {
    await db.close();
  }
}

buildSocialNetwork().catch(console.error);`,

  'social-bun': `import { NenDB } from 'nendb/bun';

const db = new NenDB({
  useFFI: true,
  fastJSON: true
});

await db.init();

try {
  // Batch create people (Bun optimized)
  const people = await db.createNodesBatch([
    { name: 'Alice', age: 28, labels: ['Person'] },
    { name: 'Bob', age: 32, labels: ['Person'] },
    { name: 'Charlie', age: 25, labels: ['Person'] }
  ]);
  
  // Batch create friendships
  await db.createEdgesBatch([
    { from: people[0], to: people[1], type: 'FRIENDS', properties: { since: '2023' } },
    { from: people[1], to: people[2], type: 'FRIENDS', properties: { since: '2024' } }
  ]);
  
  // Query with Bun's fast JSON parsing
  const network = await db.query(\`
    MATCH (a:Person)-[:FRIENDS]-(b:Person)
    RETURN a.name, b.name, a.age, b.age
  \`);
  
  console.log('Social network:', network);
  
} finally {
  await db.close();
}`,

  'recommendation': `const { NenDB } = require('nendb');

async function buildRecommendationEngine() {
  const db = new NenDB();
  await db.init();

  try {
    // Users and items
    const user1 = await db.createNode({ name: 'John', labels: ['User'] });
    const item1 = await db.createNode({ title: 'Product A', category: 'Electronics', labels: ['Product'] });
    const item2 = await db.createNode({ title: 'Product B', category: 'Electronics', labels: ['Product'] });
    
    // User interactions
    await db.createEdge(user1, item1, 'PURCHASED', { rating: 5, date: new Date().toISOString() });
    await db.createEdge(user1, item2, 'VIEWED', { duration: 30 });
    
    // Find user's activity
    const activity = await db.query(\`
      MATCH (user:User)-[action]->(product:Product)
      WHERE user.name = 'John'
      RETURN user.name, type(action) as action_type, product.title
    \`);
    
    console.log('User activity:', activity);
    
  } finally {
    await db.close();
  }
}

buildRecommendationEngine().catch(console.error);`,

  'recommendation-bun': `import { NenDB } from 'nendb/bun';

const db = new NenDB({
  useFFI: true,
  fastJSON: true,
  memorySize: 64 * 1024 * 1024 // 64MB for larger datasets
});

await db.init();

try {
  // Create users and products in batch (Bun optimized)
  const users = await db.createNodesBatch([
    { name: 'John', age: 30, labels: ['User'] },
    { name: 'Jane', age: 28, labels: ['User'] }
  ]);
  
  const products = await db.createNodesBatch([
    { title: 'Laptop Pro', category: 'Electronics', price: 1299, labels: ['Product'] },
    { title: 'Wireless Mouse', category: 'Electronics', price: 79, labels: ['Product'] },
    { title: 'Monitor 4K', category: 'Electronics', price: 399, labels: ['Product'] }
  ]);
  
  // Create interactions
  await db.createEdgesBatch([
    { from: users[0], to: products[0], type: 'PURCHASED', properties: { rating: 5, date: new Date().toISOString() } },
    { from: users[0], to: products[1], type: 'VIEWED', properties: { duration: 45 } },
    { from: users[1], to: products[0], type: 'VIEWED', properties: { duration: 120 } },
    { from: users[1], to: products[2], type: 'PURCHASED', properties: { rating: 4, date: new Date().toISOString() } }
  ]);
  
  // Advanced recommendation query
  const recommendations = await db.query(\`
    MATCH (user:User)-[:PURCHASED]->(purchased:Product)
    MATCH (other:User)-[:PURCHASED]->(purchased)
    MATCH (other)-[:PURCHASED]->(recommended:Product)
    WHERE user.name = 'John' AND NOT (user)-[:PURCHASED]->(recommended)
    RETURN recommended.title, recommended.category, recommended.price
    ORDER BY recommended.price
  \`);
  
  console.log('Recommendations for John:', recommendations);
  
} finally {
  await db.close();
}`
};

function showUsage() {
  console.log(`
🚀 NenDB Project Generator

Usage: npx nendb-create [template] [project-name]

Node.js Templates:
  basic          - Simple node creation and query example
  social         - Social network with friends and relationships  
  recommendation - Product recommendation engine pattern

Bun-Optimized Templates:
  basic-bun          - Bun-optimized basic example with FFI
  social-bun         - Social network with Bun batch operations
  recommendation-bun - Advanced recommendation engine with Bun optimizations

Examples:
  # Node.js
  npx nendb-create basic my-graph-app
  npx nendb-create social social-network
  
  # Bun-optimized
  npx nendb-create basic-bun my-bun-app
  npx nendb-create social-bun bun-social-net

Or install globally:
  npm install -g nendb
  nendb create social my-social-app
  
  # Or with Bun
  bun add -g nendb
  bun nendb-create social-bun my-bun-app
`);
}

function createProject(template, projectName) {
  if (!templates[template]) {
    console.error(`❌ Unknown template: ${template}`);
    console.log('Available templates:', Object.keys(templates).join(', '));
    process.exit(1);
  }

  const projectDir = path.resolve(projectName);
  
  if (fs.existsSync(projectDir)) {
    console.error(`❌ Directory ${projectName} already exists`);
    process.exit(1);
  }

  // Create project directory
  fs.mkdirSync(projectDir, { recursive: true });

  // Create package.json
  const isBunTemplate = template.includes('bun');
  const packageJson = {
    name: projectName,
    version: '1.0.0',
    description: `NenDB ${template} example`,
    main: 'index.js',
    type: isBunTemplate ? 'module' : 'commonjs',
    scripts: isBunTemplate ? {
      start: 'bun index.js',
      dev: 'bun --watch index.js',
      'start:node': 'node index.js'
    } : {
      start: 'node index.js',
      dev: 'node --watch index.js',
      'start:bun': 'bun index.js'
    },
    dependencies: {
      nendb: '^0.2.0'
    },
    keywords: ['nendb', 'graph-database', template, ...(isBunTemplate ? ['bun', 'bunjs'] : ['nodejs'])],
    author: '',
    license: 'MIT',
    ...(isBunTemplate && {
      engines: {
        bun: '^1.0.0'
      }
    })
  };

  fs.writeFileSync(
    path.join(projectDir, 'package.json'), 
    JSON.stringify(packageJson, null, 2)
  );

  // Create main file
  fs.writeFileSync(
    path.join(projectDir, 'index.js'), 
    templates[template]
  );

  // Create README
  const readme = `# ${projectName}

A NenDB ${template} example project.

## Setup

${isBunTemplate ? `\`\`\`bash
bun install
\`\`\`` : `\`\`\`bash
npm install
\`\`\``}

## Run

${isBunTemplate ? `\`\`\`bash
bun start      # Run with Bun (recommended)
npm run start:node  # Run with Node.js
\`\`\`` : `\`\`\`bash
npm start      # Run with Node.js
npm run start:bun   # Run with Bun (faster)
\`\`\``}

## Development

${isBunTemplate ? `\`\`\`bash
bun dev        # Auto-restart on file changes with Bun
\`\`\`` : `\`\`\`bash
npm run dev    # Auto-restart on file changes
\`\`\``}

${isBunTemplate ? `## Bun-Specific Features

This template uses Bun optimizations:
- ⚡ Faster JSON parsing with \`Bun.parseJSON()\`
- 🏃‍♂️ Optimized WebAssembly loading
- 💾 Efficient memory management with \`Bun.gc()\`
- 🕰️ High-precision timing with \`Bun.nanoseconds()\`

` : ''}## Learn More

- [NenDB Documentation](https://nen.co/docs/nendb)
- [API Reference](https://nen.co/docs/nendb/api)
- [Examples](https://github.com/Nen-Co/nen-db/blob/main/EXAMPLES.md)
${isBunTemplate ? '- [Bun Documentation](https://bun.sh/docs)' : ''}
`;

  fs.writeFileSync(path.join(projectDir, 'README.md'), readme);

  console.log(`
✅ Created ${template} project: ${projectName}

Next steps:
  cd ${projectName}
  npm install
  npm start

Happy graphing! 🎉
`);
}

// Parse command line arguments
const args = process.argv.slice(2);

if (args.length === 0 || args[0] === '--help' || args[0] === '-h') {
  showUsage();
  process.exit(0);
}

const [template, projectName] = args;

if (!projectName) {
  console.error('❌ Project name is required');
  showUsage();
  process.exit(1);
}

createProject(template, projectName);
