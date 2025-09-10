/**
 * NenDB WASM JavaScript Wrapper
 * Embedded graph database for browser and Node.js
 * 
 * Usage:
 *   import NenDB from './nendb-wasm.js';
 *   const db = await NenDB.create();
 *   const nodeId = db.addNode(123);
 *   console.log('Nodes:', db.getNodeCount());
 */

class NenDBWasm {
    constructor(wasmInstance, dbPtr) {
        this.wasm = wasmInstance;
        this.dbPtr = dbPtr;
    }

    static async create(wasmBytes) {
        // Load WASM module
        const wasmModule = await WebAssembly.instantiate(wasmBytes, {
            env: {
                // Add any required imports here
            }
        });
        
        const wasm = wasmModule.instance.exports;
        const dbPtr = wasm.nendb_wasm_create();
        
        return new NenDBWasm(wasm, dbPtr);
    }

    static async loadFromURL(wasmUrl) {
        const response = await fetch(wasmUrl);
        const wasmBytes = await response.arrayBuffer();
        return NenDBWasm.create(wasmBytes);
    }

    // Graph operations
    addNode(id) {
        const result = this.wasm.nendb_wasm_add_node(this.dbPtr, id);
        return result === 0xFFFFFFFF ? null : result;
    }

    addEdge(fromId, toId, weight = 1.0) {
        const result = this.wasm.nendb_wasm_add_edge(this.dbPtr, fromId, toId, weight);
        return result === 0xFFFFFFFF ? null : result;
    }

    // Statistics
    getNodeCount() {
        return this.wasm.nendb_wasm_get_node_count(this.dbPtr);
    }

    getEdgeCount() {
        return this.wasm.nendb_wasm_get_edge_count(this.dbPtr);
    }

    getOpsCount() {
        return this.wasm.nendb_wasm_get_ops_count(this.dbPtr);
    }

    getMemoryUsage() {
        return this.wasm.nendb_wasm_memory_usage(this.dbPtr);
    }

    getVersion() {
        const ptr = this.wasm.nendb_wasm_version();
        const memory = new Uint8Array(this.wasm.memory.buffer);
        let len = 0;
        while (memory[ptr + len] !== 0) len++;
        return new TextDecoder().decode(memory.slice(ptr, ptr + len));
    }

    // Cleanup
    destroy() {
        if (this.dbPtr) {
            this.wasm.nendb_wasm_destroy(this.dbPtr);
            this.dbPtr = null;
        }
    }
}

// Export for different module systems
if (typeof module !== 'undefined' && module.exports) {
    module.exports = NenDBWasm;
} else if (typeof window !== 'undefined') {
    window.NenDB = NenDBWasm;
} else {
    globalThis.NenDB = NenDBWasm;
}

export default NenDBWasm;
