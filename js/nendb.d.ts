export interface NenDBOptions {
  memorySize?: number;
  logLevel?: 'debug' | 'info' | 'warn' | 'error';
}

export interface GraphNode {
  id: number;
  properties: Record<string, any>;
  labels: string[];
}

export interface GraphEdge {
  id: number;
  fromNodeId: number;
  toNodeId: number;
  relationshipType: string;
  properties: Record<string, any>;
}

export interface QueryResult {
  [key: string]: any;
}

/**
 * NenDB - High-performance graph database with static memory allocation
 */
export declare class NenDB {
  constructor(options?: NenDBOptions);
  
  /**
   * Initialize the database with WASM module
   */
  init(): Promise<void>;
  
  /**
   * Create a new node in the graph
   */
  createNode(data: Record<string, any>): Promise<number>;
  
  /**
   * Create a new edge between nodes
   */
  createEdge(
    fromNodeId: number, 
    toNodeId: number, 
    relationshipType: string,
    properties?: Record<string, any>
  ): Promise<number>;
  
  /**
   * Query the graph database
   */
  query(cypherQuery: string): Promise<QueryResult[]>;
  
  /**
   * Get node by ID
   */
  getNode(nodeId: number): Promise<GraphNode | null>;
  
  /**
   * Get edge by ID
   */
  getEdge(edgeId: number): Promise<GraphEdge | null>;
  
  /**
   * Close database and free resources
   */
  close(): Promise<void>;
}

export default NenDB;
