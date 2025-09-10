import { readFileSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

/**
 * NenDB - High-performance graph database with static memory allocation
 * 
 * @example
 * ```js
 * import { NenDB } from 'nendb';
 * 
 * const db = new NenDB();
 * await db.init();
 * 
 * // Create nodes
 * const nodeId = await db.createNode({ name: 'Alice', type: 'person' });
 * 
 * // Create relationships
 * await db.createEdge(nodeId1, nodeId2, 'KNOWS', { since: '2023' });
 * 
 * // Query graph
 * const results = await db.query('MATCH (a:person)-[:KNOWS]->(b) RETURN a, b');
 * ```
 */
export class NenDB {
  constructor(options = {}) {
    this.wasmModule = null;
    this.memory = null;
    this.initialized = false;
    this.options = options;
  }

  /**
   * Initialize the database with WASM module
   */
  async init() {
    if (this.initialized) return;

    try {
      // Load WASM binary
      const wasmPath = join(__dirname, '../wasm/nendb.wasm');
      const wasmBuffer = readFileSync(wasmPath);
      
      // Create memory instance with 64MB initial, 1GB max
      this.memory = new WebAssembly.Memory({ 
        initial: 1024, // 64MB in pages
        maximum: 16384 // 1GB in pages
      });

      // Compile and instantiate WASM module
      const wasmModule = await WebAssembly.compile(wasmBuffer);
      this.wasmModule = await WebAssembly.instantiate(wasmModule, {
        env: {
          memory: this.memory,
          js_log: this.jsLog.bind(this),
          js_error: this.jsError.bind(this),
          js_timestamp: this.jsTimestamp.bind(this)
        }
      });

      // Initialize database
      const initResult = this.wasmModule.exports.nendb_init();
      if (initResult !== 0) {
        throw new Error(`Failed to initialize NenDB: ${initResult}`);
      }

      this.initialized = true;
    } catch (error) {
      throw new Error(`NenDB initialization failed: ${error.message}`);
    }
  }

  /**
   * Create a new node in the graph
   */
  async createNode(data) {
    this.ensureInitialized();
    
    const jsonData = JSON.stringify(data);
    const dataPtr = this.allocateString(jsonData);
    
    try {
      const nodeId = this.wasmModule.exports.nendb_create_node(dataPtr, jsonData.length);
      if (nodeId < 0) {
        throw new Error(`Failed to create node: ${nodeId}`);
      }
      return nodeId;
    } finally {
      this.deallocate(dataPtr);
    }
  }

  /**
   * Create a new edge between nodes
   */
  async createEdge(fromNodeId, toNodeId, relationshipType, properties = {}) {
    this.ensureInitialized();
    
    const propertiesJson = JSON.stringify(properties);
    const relationshipPtr = this.allocateString(relationshipType);
    const propertiesPtr = this.allocateString(propertiesJson);
    
    try {
      const edgeId = this.wasmModule.exports.nendb_create_edge(
        fromNodeId,
        toNodeId,
        relationshipPtr,
        relationshipType.length,
        propertiesPtr,
        propertiesJson.length
      );
      
      if (edgeId < 0) {
        throw new Error(`Failed to create edge: ${edgeId}`);
      }
      return edgeId;
    } finally {
      this.deallocate(relationshipPtr);
      this.deallocate(propertiesPtr);
    }
  }

  /**
   * Query the graph database
   */
  async query(cypherQuery) {
    this.ensureInitialized();
    
    const queryPtr = this.allocateString(cypherQuery);
    
    try {
      const resultPtr = this.wasmModule.exports.nendb_query(queryPtr, cypherQuery.length);
      if (resultPtr === 0) {
        throw new Error('Query execution failed');
      }
      
      const resultJson = this.readString(resultPtr);
      return JSON.parse(resultJson);
    } finally {
      this.deallocate(queryPtr);
    }
  }

  /**
   * Get node by ID
   */
  async getNode(nodeId) {
    this.ensureInitialized();
    
    const resultPtr = this.wasmModule.exports.nendb_get_node(nodeId);
    if (resultPtr === 0) {
      return null;
    }
    
    const nodeJson = this.readString(resultPtr);
    return JSON.parse(nodeJson);
  }

  /**
   * Get edge by ID
   */
  async getEdge(edgeId) {
    this.ensureInitialized();
    
    const resultPtr = this.wasmModule.exports.nendb_get_edge(edgeId);
    if (resultPtr === 0) {
      return null;
    }
    
    const edgeJson = this.readString(resultPtr);
    return JSON.parse(edgeJson);
  }

  /**
   * Close database and free resources
   */
  async close() {
    if (this.initialized && this.wasmModule) {
      this.wasmModule.exports.nendb_close();
      this.initialized = false;
      this.wasmModule = null;
      this.memory = null;
    }
  }

  // Private helper methods
  ensureInitialized() {
    if (!this.initialized) {
      throw new Error('NenDB not initialized. Call init() first.');
    }
  }

  allocateString(str) {
    const encoder = new TextEncoder();
    const bytes = encoder.encode(str);
    const ptr = this.wasmModule.exports.nendb_alloc(bytes.length);
    const memory = new Uint8Array(this.memory.buffer);
    memory.set(bytes, ptr);
    return ptr;
  }

  readString(ptr) {
    const memory = new Uint8Array(this.memory.buffer);
    const length = this.wasmModule.exports.nendb_get_string_length(ptr);
    const bytes = memory.slice(ptr, ptr + length);
    const decoder = new TextDecoder();
    return decoder.decode(bytes);
  }

  deallocate(ptr) {
    this.wasmModule.exports.nendb_free(ptr);
  }

  // WASM import callbacks
  jsLog(ptr, length) {
    const memory = new Uint8Array(this.memory.buffer);
    const bytes = memory.slice(ptr, ptr + length);
    const message = new TextDecoder().decode(bytes);
    console.log(`[NenDB] ${message}`);
  }

  jsError(ptr, length) {
    const memory = new Uint8Array(this.memory.buffer);
    const bytes = memory.slice(ptr, ptr + length);
    const message = new TextDecoder().decode(bytes);
    console.error(`[NenDB Error] ${message}`);
  }

  jsTimestamp() {
    return Date.now();
  }
}

// Default export for CommonJS compatibility
export default NenDB;
