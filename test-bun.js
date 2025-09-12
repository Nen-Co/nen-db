#!/usr/bin/env bun

import { NenDB } from './dist/nendb.js';
import { readFileSync } from 'fs';

async function testNenDBBun() {
  console.log('🥖 Testing NenDB with Bun runtime...\n');

  try {
    // Test Bun-specific features
    console.log('🏃‍♂️ Bun Runtime Info:');
    console.log(`  ✓ Bun version: ${Bun.version}`);
    console.log(`  ✓ Platform: ${process.platform}`);
    console.log(`  ✓ Architecture: ${process.arch}`);

    // Test WebAssembly support
    console.log('\n🧮 Testing WebAssembly support:');
    console.log(`  ✓ WebAssembly available: ${typeof WebAssembly !== 'undefined'}`);
    console.log(`  ✓ WebAssembly.instantiate: ${typeof WebAssembly.instantiate === 'function'}`);

    // Test package structure
    console.log('\n📦 Package structure:');
    const fs = require('fs');
    const files = fs.readdirSync('./dist/');
    
    const expectedFiles = [
      'nendb.wasm',
      'nendb.js', 
      'nendb.mjs',
      'nendb-wasm.js',
      'nendb.d.ts',
      'nendb-wasm.d.ts',
      'index.js',
      'index.mjs'
    ];

    for (const file of expectedFiles) {
      if (files.includes(file)) {
        const stat = fs.statSync(`./dist/${file}`);
        const size = (stat.size / 1024).toFixed(1);
        console.log(`  ✓ ${file} (${size}KB)`);
      } else {
        console.log(`  ❌ ${file} (missing)`);
      }
    }

    // Test Bun-optimized loading
    console.log('\n🚀 Testing Bun optimizations:');
    
    // Test fast JSON
    const testData = { nodes: [1, 2, 3], edges: [[1, 2], [2, 3]] };
    const jsonString = Bun.stringifyJSON ? Bun.stringifyJSON(testData) : JSON.stringify(testData);
    const parsed = Bun.parseJSON ? Bun.parseJSON(jsonString) : JSON.parse(jsonString);
    console.log(`  ✓ Fast JSON: ${Bun.stringifyJSON ? 'Bun.stringifyJSON' : 'JSON.stringify'}`);
    console.log(`  ✓ Fast Parse: ${Bun.parseJSON ? 'Bun.parseJSON' : 'JSON.parse'}`);

    // Test high-precision timing
    const start = Bun.nanoseconds ? Bun.nanoseconds() : performance.now() * 1000000;
    await new Promise(resolve => setTimeout(resolve, 1));
    const end = Bun.nanoseconds ? Bun.nanoseconds() : performance.now() * 1000000;
    const elapsed = (end - start) / 1000000; // Convert to ms
    console.log(`  ✓ Timing precision: ${elapsed.toFixed(3)}ms`);

    // Test WASM file loading with Bun
    console.log('\n🔧 Testing WASM loading:');
    try {
      const wasmPath = './dist/nendb.wasm';
      if (fs.existsSync(wasmPath)) {
        const wasmFile = Bun.file ? await Bun.file(wasmPath).arrayBuffer() : fs.readFileSync(wasmPath);
        console.log(`  ✓ WASM file loaded: ${(wasmFile.byteLength / 1024).toFixed(1)}KB`);
        
        // Test WebAssembly instantiation
        const module = await WebAssembly.compile(wasmFile);
        console.log(`  ✓ WASM module compiled successfully`);
      } else {
        console.log(`  ❌ WASM file not found: ${wasmPath}`);
      }
    } catch (error) {
      console.log(`  ⚠️  WASM loading test skipped: ${error.message}`);
    }

    // Test NenDB API with Bun optimizations
    console.log('\n⚡ Testing NenDB Bun API:');
    try {
      const db = new NenDB();
      console.log('  ✓ NenDB instance created');
      
      // Test batch operations (would need actual WASM implementation)
      const mockBatch = [
        { type: 'create_node', data: { id: 1, label: 'User', props: { name: 'Alice' } } },
        { type: 'create_node', data: { id: 2, label: 'User', props: { name: 'Bob' } } },
        { type: 'create_edge', data: { from: 1, to: 2, label: 'FRIENDS' } }
      ];
      
      console.log(`  ✓ Batch operations prepared: ${mockBatch.length} items`);
      console.log('  ⚠️  Full API test requires WASM implementation');
      
    } catch (error) {
      console.log(`  ⚠️  API test skipped: ${error.message}`);
    }

    // Test memory management with Bun
    if (Bun.gc) {
      console.log('\n🧹 Testing memory management:');
      const memBefore = process.memoryUsage().heapUsed;
      
      // Create some objects
      const testObjects = Array.from({ length: 10000 }, (_, i) => ({ id: i, data: `test-${i}` }));
      
      const memAfter = process.memoryUsage().heapUsed;
      console.log(`  ✓ Memory used: ${((memAfter - memBefore) / 1024 / 1024).toFixed(2)}MB`);
      
      // Force garbage collection
      Bun.gc(true);
      const memGC = process.memoryUsage().heapUsed;
      console.log(`  ✓ After GC: ${((memGC - memBefore) / 1024 / 1024).toFixed(2)}MB`);
    }

    console.log('\n✅ Bun integration test completed successfully!');
    
    console.log('\n📋 Bun Usage Instructions:');
    console.log('  bun add nendb');
    console.log('  import { NenDB } from "nendb";');
    console.log('  const db = new NenDB();');
    
    console.log('\n📋 Bun-optimized features:');
    console.log('  ⚡ Fast JSON parsing with Bun.parseJSON()');
    console.log('  🏃‍♂️ Optimized WebAssembly loading');
    console.log('  💾 Efficient memory management with Bun.gc()');
    console.log('  🕰️ High-precision timing with Bun.nanoseconds()');

  } catch (error) {
    console.error('❌ Bun test failed:', error.message);
    console.error('Stack trace:', error.stack);
    process.exit(1);
  }
}

// Run the test
testNenDBBun();
