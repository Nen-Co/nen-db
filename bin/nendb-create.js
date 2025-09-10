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

buildRecommendationEngine().catch(console.error);`
};

function showUsage() {
  console.log(`
🚀 NenDB Project Generator

Usage: npx nendb-create [template] [project-name]

Templates:
  basic          - Simple node creation and query example
  social         - Social network with friends and relationships  
  recommendation - Product recommendation engine pattern

Examples:
  npx nendb-create basic my-graph-app
  npx nendb-create social social-network
  npx nendb-create recommendation rec-engine

Or install globally:
  npm install -g nendb
  nendb create social my-social-app
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
  const packageJson = {
    name: projectName,
    version: '1.0.0',
    description: `NenDB ${template} example`,
    main: 'index.js',
    scripts: {
      start: 'node index.js',
      dev: 'node --watch index.js'
    },
    dependencies: {
      nendb: '^0.2.0'
    },
    keywords: ['nendb', 'graph-database', template],
    author: '',
    license: 'MIT'
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

\`\`\`bash
npm install
\`\`\`

## Run

\`\`\`bash
npm start
\`\`\`

## Development

\`\`\`bash
npm run dev  # Auto-restart on file changes
\`\`\`

## Learn More

- [NenDB Documentation](https://nen.co/docs/nendb)
- [API Reference](https://nen.co/docs/nendb/api)
- [Examples](https://github.com/Nen-Co/nen-db/blob/main/EXAMPLES.md)
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
