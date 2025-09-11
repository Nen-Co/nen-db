#!/usr/bin/env node

const fs = require('fs');
const path = require('path');

const rootDir = path.join(__dirname, '..');
const distDir = path.join(rootDir, 'dist');
const jsDir = path.join(rootDir, 'js');
const wasmDir = path.join(rootDir, 'wasm');

// Create dist directory
if (!fs.existsSync(distDir)) {
  fs.mkdirSync(distDir, { recursive: true });
}

console.log('Building NPM package...');

// Copy JavaScript files
console.log('Copying JavaScript files...');
fs.copyFileSync(path.join(jsDir, 'nendb.js'), path.join(distDir, 'nendb.js'));
fs.copyFileSync(path.join(jsDir, 'nendb.mjs'), path.join(distDir, 'nendb.mjs'));
fs.copyFileSync(path.join(jsDir, 'nendb.d.ts'), path.join(distDir, 'nendb.d.ts'));

// Copy Bun-optimized version
if (fs.existsSync(path.join(jsDir, 'nendb.bun.mjs'))) {
  console.log('Copying Bun-optimized files...');
  fs.copyFileSync(path.join(jsDir, 'nendb.bun.mjs'), path.join(distDir, 'nendb.bun.mjs'));
}

// Copy WASM files if they exist
const wasmFile = path.join(rootDir, 'zig-out/bin/nendb-wasm.wasm');
if (fs.existsSync(wasmFile)) {
  console.log('Copying WASM files...');
  fs.copyFileSync(wasmFile, path.join(distDir, 'nendb.wasm'));
} else {
  console.warn('WASM file not found. Run `zig build wasm --release=small` first.');
}

// Copy existing WASM JS wrapper
const wasmJsFile = path.join(wasmDir, 'nendb-wasm.js');
if (fs.existsSync(wasmJsFile)) {
  fs.copyFileSync(wasmJsFile, path.join(distDir, 'nendb-wasm.js'));
}

// Create browser-specific WASM package files
console.log('Creating browser WASM wrapper...');
const browserWrapper = `/**
 * NenDB WASM - Browser-optimized WebAssembly graph database
 */

class NenDBWasm {
  constructor(options = {}) {
    this.wasmModule = null;
    this.memory = null;
    this.initialized = false;
    this.options = options;
  }

  /**
   * Initialize with WASM module from URL or ArrayBuffer
   */
  async init(wasmSource) {
    if (this.initialized) return;

    try {
      let wasmBuffer;
      
      if (typeof wasmSource === 'string') {
        // Load from URL
        const response = await fetch(wasmSource);
        wasmBuffer = await response.arrayBuffer();
      } else if (wasmSource instanceof ArrayBuffer) {
        wasmBuffer = wasmSource;
      } else {
        throw new Error('WASM source must be URL string or ArrayBuffer');
      }

      // Create memory instance
      this.memory = new WebAssembly.Memory({ 
        initial: 1024, // 64MB
        maximum: 16384 // 1GB
      });

      // Compile and instantiate
      const wasmModule = await WebAssembly.compile(wasmBuffer);
      this.wasmModule = await WebAssembly.instantiate(wasmModule, {
        env: {
          memory: this.memory,
          js_log: (ptr, len) => this.jsLog(ptr, len),
          js_error: (ptr, len) => this.jsError(ptr, len),
          js_timestamp: () => Date.now()
        }
      });

      // Initialize
      const result = this.wasmModule.exports.nendb_init();
      if (result !== 0) {
        throw new Error(\`Init failed: \${result}\`);
      }

      this.initialized = true;
    } catch (error) {
      throw new Error(\`NenDB WASM init failed: \${error.message}\`);
    }
  }

  async createNode(data) {
    this.ensureInitialized();
    const jsonData = JSON.stringify(data);
    const dataPtr = this.allocateString(jsonData);
    try {
      const nodeId = this.wasmModule.exports.nendb_create_node(dataPtr, jsonData.length);
      if (nodeId < 0) throw new Error(\`Create node failed: \${nodeId}\`);
      return nodeId;
    } finally {
      this.deallocate(dataPtr);
    }
  }

  async createEdge(fromId, toId, type, props = {}) {
    this.ensureInitialized();
    const propsJson = JSON.stringify(props);
    const typePtr = this.allocateString(type);
    const propsPtr = this.allocateString(propsJson);
    try {
      const edgeId = this.wasmModule.exports.nendb_create_edge(
        fromId, toId, typePtr, type.length, propsPtr, propsJson.length
      );
      if (edgeId < 0) throw new Error(\`Create edge failed: \${edgeId}\`);
      return edgeId;
    } finally {
      this.deallocate(typePtr);
      this.deallocate(propsPtr);
    }
  }

  async query(cypherQuery) {
    this.ensureInitialized();
    const queryPtr = this.allocateString(cypherQuery);
    try {
      const resultPtr = this.wasmModule.exports.nendb_query(queryPtr, cypherQuery.length);
      if (resultPtr === 0) throw new Error('Query failed');
      return JSON.parse(this.readString(resultPtr));
    } finally {
      this.deallocate(queryPtr);
    }
  }

  async close() {
    if (this.initialized && this.wasmModule) {
      this.wasmModule.exports.nendb_close();
      this.initialized = false;
    }
  }

  ensureInitialized() {
    if (!this.initialized) throw new Error('Not initialized');
  }

  allocateString(str) {
    const encoder = new TextEncoder();
    const bytes = encoder.encode(str);
    const ptr = this.wasmModule.exports.nendb_alloc(bytes.length);
    new Uint8Array(this.memory.buffer).set(bytes, ptr);
    return ptr;
  }

  readString(ptr) {
    const memory = new Uint8Array(this.memory.buffer);
    const length = this.wasmModule.exports.nendb_get_string_length(ptr);
    return new TextDecoder().decode(memory.slice(ptr, ptr + length));
  }

  deallocate(ptr) {
    this.wasmModule.exports.nendb_free(ptr);
  }

  jsLog(ptr, length) {
    const memory = new Uint8Array(this.memory.buffer);
    const message = new TextDecoder().decode(memory.slice(ptr, ptr + length));
    console.log(\`[NenDB] \${message}\`);
  }

  jsError(ptr, length) {
    const memory = new Uint8Array(this.memory.buffer);
    const message = new TextDecoder().decode(memory.slice(ptr, ptr + length));
    console.error(\`[NenDB Error] \${message}\`);
  }
}

// For module systems
if (typeof module !== 'undefined' && module.exports) {
  module.exports = { NenDBWasm };
  module.exports.default = NenDBWasm;
}

// For ES modules
if (typeof window !== 'undefined') {
  window.NenDBWasm = NenDBWasm;
}
`;

fs.writeFileSync(path.join(distDir, 'nendb-wasm.js'), browserWrapper);

// Create TypeScript definitions for WASM
const wasmDts = `export declare class NenDBWasm {
  constructor(options?: any);
  init(wasmSource: string | ArrayBuffer): Promise<void>;
  createNode(data: Record<string, any>): Promise<number>;
  createEdge(fromId: number, toId: number, type: string, props?: Record<string, any>): Promise<number>;
  query(cypherQuery: string): Promise<any[]>;
  close(): Promise<void>;
}

export default NenDBWasm;`;

fs.writeFileSync(path.join(distDir, 'nendb-wasm.d.ts'), wasmDts);

// Create main index files
const indexJs = `module.exports = require('./nendb.js');`;
fs.writeFileSync(path.join(distDir, 'index.js'), indexJs);

const indexMjs = `export * from './nendb.mjs';
export { default } from './nendb.mjs';`;
fs.writeFileSync(path.join(distDir, 'index.mjs'), indexMjs);

console.log('✅ Build complete!');
console.log('Generated files:');
console.log('  - dist/nendb.js (CommonJS)');
console.log('  - dist/nendb.mjs (ES Modules)');
console.log('  - dist/nendb.d.ts (TypeScript definitions)');
console.log('  - dist/nendb-wasm.js (Browser WASM)');
console.log('  - dist/nendb-wasm.d.ts (WASM TypeScript definitions)');
console.log('  - dist/index.js (Main entry point)');
