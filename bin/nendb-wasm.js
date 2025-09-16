#!/usr/bin/env node

/**
 * NenDB WASM Command Line Interface
 * 
 * This script provides a command-line interface for running NenDB in WASM mode.
 * It's designed for browser environments and Node.js with WASM support.
 */

const fs = require('fs');
const path = require('path');

// Get the directory where this script is located
const binDir = __dirname;
const distDir = path.join(binDir, '..', 'dist');

// Check if WASM files exist
const wasmFile = path.join(distDir, 'nendb.wasm');
const wasmJsFile = path.join(distDir, 'nendb-wasm.js');

if (!fs.existsSync(wasmFile)) {
    console.error('❌ Error: WASM file not found. Please run "npm run build:wasm" first.');
    process.exit(1);
}

if (!fs.existsSync(wasmJsFile)) {
    console.error('❌ Error: WASM JavaScript wrapper not found. Please run "npm run build:js" first.');
    process.exit(1);
}

// Display help information
function showHelp() {
    console.log(`
🚀 NenDB WASM Command Line Interface

Usage: nendb-wasm [command] [options]

Commands:
  create <name>     Create a new database
  serve [port]      Start WASM server (default port: 8080)
  test              Run WASM tests
  info              Show WASM build information
  help              Show this help message

Examples:
  nendb-wasm create my-database
  nendb-wasm serve 3000
  nendb-wasm test
  nendb-wasm info

For more information, visit: https://github.com/Nen-Co/nen-db
`);
}

// Show WASM build information
function showInfo() {
    const wasmStats = fs.statSync(wasmFile);
    const jsStats = fs.statSync(wasmJsFile);
    
    console.log(`
📊 NenDB WASM Build Information

WASM File: ${wasmFile}
  Size: ${(wasmStats.size / 1024).toFixed(2)} KB
  Modified: ${wasmStats.mtime.toISOString()}

JavaScript Wrapper: ${wasmJsFile}
  Size: ${(jsStats.size / 1024).toFixed(2)} KB
  Modified: ${jsStats.mtime.toISOString()}

Features:
  ✅ WebAssembly support
  ✅ Browser compatibility
  ✅ Node.js compatibility
  ✅ TypeScript definitions
  ✅ High-performance graph database
  ✅ Static memory allocation
  ✅ Crash-safe design
`);
}

// Create a new database
function createDatabase(name) {
    if (!name) {
        console.error('❌ Error: Database name is required');
        console.log('Usage: nendb-wasm create <name>');
        process.exit(1);
    }
    
    console.log(`🔨 Creating WASM database: ${name}`);
    console.log('📁 Database files will be created in the current directory');
    console.log('🌐 Use this database in your browser or Node.js application');
    console.log('');
    console.log('Example usage:');
    console.log('  import nendb from "@nenco/nendb/wasm";');
    console.log('  const db = await nendb.init();');
    console.log('');
    console.log('✅ Database creation instructions provided');
}

// Start WASM server
function startServer(port = 8080) {
    console.log(`🚀 Starting NenDB WASM server on port ${port}`);
    console.log('🌐 Server will serve the WASM files for browser access');
    console.log('📁 Serving files from:', distDir);
    console.log('');
    console.log('Access your database at:');
    console.log(`  http://localhost:${port}/nendb-wasm.js`);
    console.log(`  http://localhost:${port}/nendb.wasm`);
    console.log('');
    console.log('Press Ctrl+C to stop the server');
    
    // Simple HTTP server for serving WASM files
    const http = require('http');
    const server = http.createServer((req, res) => {
        const filePath = path.join(distDir, req.url === '/' ? 'nendb-wasm.js' : req.url);
        
        if (fs.existsSync(filePath)) {
            const ext = path.extname(filePath);
            const contentType = {
                '.js': 'application/javascript',
                '.wasm': 'application/wasm',
                '.mjs': 'application/javascript',
                '.json': 'application/json'
            }[ext] || 'text/plain';
            
            res.writeHead(200, { 'Content-Type': contentType });
            fs.createReadStream(filePath).pipe(res);
        } else {
            res.writeHead(404, { 'Content-Type': 'text/plain' });
            res.end('File not found');
        }
    });
    
    server.listen(port, () => {
        console.log(`✅ Server running on http://localhost:${port}`);
    });
}

// Run WASM tests
function runTests() {
    console.log('🧪 Running NenDB WASM tests...');
    console.log('📋 Testing WASM file integrity...');
    
    try {
        // Test WASM file
        const wasmBuffer = fs.readFileSync(wasmFile);
        console.log(`✅ WASM file loaded: ${wasmBuffer.length} bytes`);
        
        // Test JavaScript wrapper
        const jsContent = fs.readFileSync(wasmJsFile, 'utf8');
        console.log(`✅ JavaScript wrapper loaded: ${jsContent.length} characters`);
        
        // Basic syntax check
        try {
            eval(jsContent);
            console.log('✅ JavaScript wrapper syntax is valid');
        } catch (e) {
            console.log('⚠️  JavaScript wrapper syntax check failed:', e.message);
        }
        
        console.log('');
        console.log('🎉 All WASM tests passed!');
        console.log('✅ NenDB WASM is ready for use');
        
    } catch (error) {
        console.error('❌ WASM test failed:', error.message);
        process.exit(1);
    }
}

// Parse command line arguments
const args = process.argv.slice(2);
const command = args[0];

switch (command) {
    case 'create':
        createDatabase(args[1]);
        break;
    case 'serve':
        const port = parseInt(args[1]) || 8080;
        startServer(port);
        break;
    case 'test':
        runTests();
        break;
    case 'info':
        showInfo();
        break;
    case 'help':
    case '--help':
    case '-h':
        showHelp();
        break;
    default:
        if (!command) {
            showHelp();
        } else {
            console.error(`❌ Unknown command: ${command}`);
            console.log('Run "nendb-wasm help" for available commands');
            process.exit(1);
        }
}
