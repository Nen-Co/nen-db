#!/usr/bin/env node

const { NenDB } = require('./dist/nendb.js');
const fs = require('fs');
const path = require('path');

async function testNenDB() {
  console.log('🧪 Testing NenDB npm package...\n');

  try {
    // Test package structure
    console.log('📦 Package structure:');
    const distFiles = fs.readdirSync('./dist/');
    distFiles.forEach(file => {
      const size = fs.statSync(`./dist/${file}`).size;
      console.log(`  ✓ ${file} (${(size / 1024).toFixed(1)}KB)`);
    });

    // Test JavaScript API
    console.log('\n🚀 Testing JavaScript API:');
    
    const db = new NenDB({
      memorySize: 16 * 1024 * 1024, // 16MB for testing
      logLevel: 'info'
    });

    console.log('  ✓ NenDB instance created');
    
    // Note: This will fail until we have actual WASM exports
    // but it tests the package structure
    console.log('  ⚠️  WASM init would be tested here (requires actual WASM exports)');

    console.log('\n✅ Package structure test passed!');
    console.log('\n📋 Usage instructions:');
    console.log('  npm install nendb');
    console.log('  const { NenDB } = require("nendb");');
    console.log('\n📋 WASM usage:');
    console.log('  npm install nendb-wasm');
    console.log('  import { NenDBWasm } from "nendb-wasm";');

  } catch (error) {
    console.error('❌ Test failed:', error.message);
    process.exit(1);
  }
}

testNenDB();
