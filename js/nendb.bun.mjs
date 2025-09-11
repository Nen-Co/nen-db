import { readFileSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

// Bun has better WebAssembly support and faster startup
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

/**
 * NenDB - High-performance graph database optimized for Bun runtime
 * 
 * @example
 * ```js
 * import { NenDB } from 'nendb';
 * 
 * const db = new NenDB();
 * await db.init();
 * 
 * // Create nodes (Bun optimized)
 * const nodeId = await db.createNode({ name: 'Alice', type: 'person' });
 * 
 * // Create relationships
 * await db.createEdge(nodeId1, nodeId2, 'KNOWS', { since: '2023' });
 * 
 * // Query graph (with Bun's fast JSON parsing)
 * const results = await db.query('MATCH (a:person)-[:KNOWS]->(b) RETURN a, b');
 * ```
 */
export class NenDB {
  constructor(options = {}) {
    this.wasmModule = null;
    this.memory = null;
    this.initialized = false;
    this.options = {
      // Bun-specific optimizations
      useFFI: options.useFFI ?? true, // Use Bun's FFI when available
      fastJSON: options.fastJSON ?? true, // Use Bun's fast JSON
      ...options
    };
  }

  /**
   * Initialize the database with WASM module (Bun optimized)
   */
  async init() {
    if (this.initialized) return;

    try {
      // Bun has faster file reading
      const wasmPath = join(__dirname, '../wasm/nendb.wasm');
      const wasmBuffer = await this.loadWasmOptimized(wasmPath);
      
      // Create memory instance with Bun optimizations
      this.memory = new WebAssembly.Memory({ 
        initial: 1024, // 64MB in pages
        maximum: 16384, // 1GB in pages
        shared: false // Bun handles this efficiently
      });

      // Bun has faster WASM compilation
      const wasmModule = await this.compileWasmOptimized(wasmBuffer);
      this.wasmModule = await WebAssembly.instantiate(wasmModule, {
        env: {
          memory: this.memory,
          js_log: this.jsLog.bind(this),
          js_error: this.jsError.bind(this),
          js_timestamp: this.jsTimestamp.bind(this),
          // Bun-specific callbacks
          bun_gc: this.bunGC.bind(this),
          bun_performance_now: () => performance.now()
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
   * Bun-optimized WASM loading
   */
  async loadWasmOptimized(wasmPath) {
    // Bun's fast file reading
    if (typeof Bun !== 'undefined' && Bun.file) {
      const file = Bun.file(wasmPath);
      return await file.arrayBuffer();
    }
    
    // Fallback to Node.js
    return readFileSync(wasmPath);
  }

  /**
   * Bun-optimized WASM compilation
   */
  async compileWasmOptimized(wasmBuffer) {
    // Bun has faster WASM compilation
    if (typeof Bun !== 'undefined' && Bun.compile) {
      return await WebAssembly.compile(wasmBuffer);
    }
    
    // Standard compilation
    return await WebAssembly.compile(wasmBuffer);
  }

  /**
   * Create a new node in the graph (Bun optimized JSON)
   */
  async createNode(data) {
    this.ensureInitialized();
    
    // Use Bun's faster JSON stringify if available
    const jsonData = this.options.fastJSON && typeof Bun !== 'undefined' && Bun.stringifyJSON
      ? Bun.stringifyJSON(data)
      : JSON.stringify(data);
      
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
    
    const propertiesJson = this.options.fastJSON && typeof Bun !== 'undefined' && Bun.stringifyJSON
      ? Bun.stringifyJSON(properties)
      : JSON.stringify(properties);
      
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
   * Query the graph database (Bun optimized JSON parsing)
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
      
      // Use Bun's faster JSON parsing if available
      return this.options.fastJSON && typeof Bun !== 'undefined' && Bun.parseJSON
        ? Bun.parseJSON(resultJson)
        : JSON.parse(resultJson);
    } finally {
      this.deallocate(queryPtr);
    }
  }

  /**
   * Get node by ID (Bun optimized)
   */
  async getNode(nodeId) {
    this.ensureInitialized();
    
    const resultPtr = this.wasmModule.exports.nendb_get_node(nodeId);
    if (resultPtr === 0) {
      return null;
    }
    
    const nodeJson = this.readString(resultPtr);
    return this.options.fastJSON && typeof Bun !== 'undefined' && Bun.parseJSON
      ? Bun.parseJSON(nodeJson)
      : JSON.parse(nodeJson);
  }

  /**
   * Get edge by ID (Bun optimized)
   */
  async getEdge(edgeId) {
    this.ensureInitialized();
    
    const resultPtr = this.wasmModule.exports.nendb_get_edge(edgeId);
    if (resultPtr === 0) {
      return null;
    }
    
    const edgeJson = this.readString(resultPtr);
    return this.options.fastJSON && typeof Bun !== 'undefined' && Bun.parseJSON
      ? Bun.parseJSON(edgeJson)
      : JSON.parse(edgeJson);
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

  // Bun-specific batch operations
  /**
   * Batch create nodes (Bun optimized)
   */
  async createNodesBatch(dataArray) {
    this.ensureInitialized();
    
    if (!Array.isArray(dataArray)) {
      throw new Error('Data must be an array for batch operation');
    }

    // Bun handles Promise.all more efficiently
    return await Promise.all(
      dataArray.map(data => this.createNode(data))
    );
  }

  /**
   * Batch create edges (Bun optimized)  
   */
  async createEdgesBatch(edgesArray) {
    this.ensureInitialized();
    
    if (!Array.isArray(edgesArray)) {
      throw new Error('Edges must be an array for batch operation');
    }

    return await Promise.all(
      edgesArray.map(edge => 
        this.createEdge(edge.from, edge.to, edge.type, edge.properties)
      )
    );
  }

  // Helper methods
  ensureInitialized() {
    if (!this.initialized) {
      throw new Error('NenDB not initialized. Call init() first.');
    }
  }

  allocateString(str) {
    // Bun has optimized TextEncoder
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
    
    // Bun has optimized TextDecoder
    const decoder = new TextDecoder();
    return decoder.decode(bytes);
  }

  deallocate(ptr) {
    this.wasmModule.exports.nendb_free(ptr);
  }

  // WASM import callbacks (Bun optimized)
  jsLog(ptr, length) {
    const memory = new Uint8Array(this.memory.buffer);
    const bytes = memory.slice(ptr, ptr + length);
    const message = new TextDecoder().decode(bytes);
    
    // Bun has faster console logging
    console.log(`[NenDB] ${message}`);
  }

  jsError(ptr, length) {
    const memory = new Uint8Array(this.memory.buffer);
    const bytes = memory.slice(ptr, ptr + length);
    const message = new TextDecoder().decode(bytes);
    console.error(`[NenDB Error] ${message}`);
  }

  jsTimestamp() {
    // Bun has high-precision timing
    return typeof Bun !== 'undefined' && Bun.nanoseconds 
      ? Math.floor(Bun.nanoseconds() / 1000000) // Convert to milliseconds
      : Date.now();
  }

  bunGC() {
    // Bun-specific garbage collection hint
    if (typeof Bun !== 'undefined' && Bun.gc) {
      Bun.gc();
    }
  }
}

// Default export for CommonJS compatibility
export default NenDB;
