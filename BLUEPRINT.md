# NenDB Blueprint

## Overview

This document outlines our roadmap to build a production-ready graph database while leveraging NenDB's unique strengths in static memory management, Zig performance optimizations, and crash-safe persistence.

## Current Status vs. Target

### ✅ **What We Already Have (Production-Ready)**

1. **Core Graph Operations**
   - Node/Edge CRUD operations with static memory pools
   - Basic graph traversal framework
   - Lock-free reads, mutex-guarded writes
   - WAL with crash-safe persistence and segment rotation
   - Atomic snapshots with .bak fallback
   - LSN-aware recovery system

2. **Query Language Foundation**
   - Cypher-like parser (basic MATCH, CREATE, DELETE, SET)
   - AST structure for query parsing
   - Query executor framework
   - Basic algorithm hints (BFS, DIJKSTRA, PAGERANK)

3. **Infrastructure & Operations**
   - CLI with admin commands (init, status, snapshot, restore, check, compact)
   - Health monitoring and status reporting
   - Memory pool management (nodes, edges, embeddings)
   - Resource monitoring (CPU, RSS, IO counters)
   - Single-writer process model with lock file protection

### 🎯 **Target: FalkorDB Feature Parity**

## Implementation Roadmap

### **Phase 1: Core Graph Algorithms (Weeks 1-2)**

#### **1.1 Graph Traversal Algorithms**
```zig
// nen-db/src/algorithms/
- bfs.zig              // Breadth-first search
- dfs.zig              // Depth-first search  
- dijkstra.zig         // Shortest path algorithm
- pagerank.zig         // PageRank algorithm
- connected_components.zig  // Weakly connected components
```

**Priority**: HIGH - Core functionality needed for graph operations

#### **1.2 Advanced Graph Algorithms**
```zig
// nen-db/src/algorithms/
- betweenness_centrality.zig  // Betweenness centrality
- community_detection.zig     // Label propagation
- sp_paths.zig               // Shortest paths (multiple)
- ss_paths.zig               // Single source paths
```

**Priority**: MEDIUM - Advanced analytics capabilities

### **Phase 2: Enhanced Cypher Language (Weeks 3-4)**

#### **2.1 Query Clauses**
```zig
// Extend nen-db/src/query/cypher/
- OPTIONAL MATCH support
- WHERE clauses with complex expressions (AND, OR, NOT, IN, etc.)
- ORDER BY, SKIP, LIMIT operations
- MERGE operations (CREATE if not exists)
- WITH clauses for intermediate results
- UNION operations
- UNWIND operations for list processing
- FOREACH loops for batch operations
```

#### **2.2 Functions & Procedures**
```zig
// nen-db/src/query/functions/
- Mathematical functions (abs, round, ceil, floor)
- String functions (substring, toUpper, toLower)
- Aggregation functions (count, sum, avg, min, max)
- Graph functions (degree, neighbors, path)
- Custom procedures framework
```

#### **2.3 Indexing & Constraints**
```zig
// nen-db/src/indexing/
- Property indexes for fast lookups
- Full-text search indexes
- Vector similarity indexes
- Constraint validation (UNIQUE, NOT NULL)
- Index maintenance and optimization
```

**Priority**: HIGH - Query language completeness

### **Phase 3: Graph Commands & API (Weeks 5-6)**

#### **3.1 Core Graph Commands**
```zig
// nen-db/src/commands/
- GRAPH.QUERY      // Main query interface with algorithm selection
- GRAPH.RO_QUERY  // Read-only queries (no locks)
- GRAPH.DELETE    // Delete entire graphs
- GRAPH.EXPLAIN   // Query execution plan
- GRAPH.LIST      // List available graphs
- GRAPH.PROFILE   // Query performance profiling
```

#### **3.2 Management Commands**
```zig
// nen-db/src/commands/
- GRAPH.CONFIG-GET/SET  // Configuration management
- GRAPH.CONSTRAINT CREATE/DROP  // Constraint management
- GRAPH.COPY      // Graph duplication
- GRAPH.INFO      // Graph statistics and metadata
- GRAPH.MEMORY    // Memory usage breakdown
- GRAPH.SLOWLOG   // Slow query logging
```

#### **3.3 REST API & Protocols**
```zig
// nen-db/src/api/
- HTTP REST API endpoints
- WebSocket support for real-time updates
- RESP protocol (Redis-style) compatibility
- Bolt protocol support (Neo4j compatibility)
```

**Priority**: HIGH - Production API completeness

### **Phase 4: Advanced Features (Weeks 7-8)**

#### **4.1 Search & Analytics**
```zig
// nen-db/src/features/
- Full-text search with relevance scoring
- Vector similarity search (embeddings)
- Numeric range queries
- Graph analytics dashboard
- Export capabilities (CSV, JSON, GraphML)
```

#### **4.2 Multi-tenancy & Operations**
```zig
// nen-db/src/features/
- Multi-tenant graph isolation
- Graph partitioning and sharding
- Background compaction and optimization
- Metrics collection and monitoring
- Health checks and alerting
```

**Priority**: MEDIUM - Enterprise features

### **Phase 5: Client Libraries & Integration (Weeks 9-10)**

#### **5.1 Client Libraries**
```zig
// nen-db/src/clients/
- Python client (using nen-net)
- JavaScript/Node.js client
- Rust client
- Java client
- Shell/CLI client
```

#### **5.2 External Integrations**
```zig
// nen-db/src/integrations/
- Kafka Connect Sink
- Kubernetes deployment
- Docker containerization
- Monitoring integrations (Prometheus, Grafana)
```

**Priority**: MEDIUM - Ecosystem completeness

## Technical Architecture

### **Memory Management Strategy**
- **Keep Static Memory Model**: Our static memory pools are a key differentiator
- **Algorithm Implementation**: Use existing memory pool structure for efficient traversal
- **Query Optimization**: Leverage static memory layout for predictable performance
- **Memory Pool Extensions**: Add algorithm-specific memory pools as needed

### **Performance Optimizations**
- **Zero-Copy Operations**: Minimize memory allocations in hot paths
- **Cache-Aware Algorithms**: Design algorithms around our memory pool layout
- **Batch Processing**: Group operations for better throughput
- **Compile-Time Optimizations**: Use Zig's comptime features for algorithm variants

### **Concurrency Model**
- **Single Writer**: Maintain our proven single-writer model
- **Lock-Free Reads**: Extend lock-free operations to algorithm execution
- **Read Replicas**: Future consideration for read scaling
- **Background Workers**: Non-blocking maintenance operations

## Success Metrics

### **Phase 1 Success Criteria**
- [ ] BFS algorithm handles graphs up to 1M nodes
- [ ] Dijkstra finds shortest paths in <10ms for 100K node graphs
- [ ] PageRank converges in <100 iterations for typical graphs
- [ ] All algorithms work with existing memory pool structure

### **Phase 2 Success Criteria**
- [ ] Cypher parser handles 90%+ of FalkorDB query syntax
- [ ] Query execution time within 2x of FalkorDB for equivalent operations
- [ ] Index lookups provide 10x+ speedup for property queries

### **Phase 3 Success Criteria**
- [ ] All core GRAPH commands implemented and tested
- [ ] REST API handles 1000+ concurrent connections
- [ ] Query profiling provides actionable performance insights

## Risk Mitigation

### **Technical Risks**
- **Algorithm Complexity**: Start with simple implementations, optimize incrementally
- **Memory Constraints**: Monitor memory usage, add pool size configuration
- **Performance Degradation**: Benchmark continuously, maintain performance baselines

### **Timeline Risks**
- **Scope Creep**: Stick to phased approach, defer non-essential features
- **Integration Complexity**: Test each component independently before integration
- **Documentation Debt**: Document as we build, not after completion

## Next Steps

1. **Immediate (This Week)**
   - [ ] Implement BFS algorithm
   - [ ] Add algorithm selection to query engine
   - [ ] Create algorithm testing framework

2. **Week 2**
   - [ ] Implement Dijkstra's algorithm
   - [ ] Implement PageRank
   - [ ] Performance benchmarking

3. **Week 3**
   - [ ] Extend Cypher WHERE clauses
   - [ ] Add ORDER BY, SKIP, LIMIT
   - [ ] Implement basic indexing

## Conclusion

This blueprint provides a clear path to build a production-ready graph database while leveraging NenDB's unique strengths. The phased approach ensures we deliver value incrementally while maintaining our core architectural principles.

**Key Success Factors:**
- Maintain static memory model advantages
- Leverage Zig's performance characteristics
- Build on proven WAL and snapshot infrastructure
- Focus on core algorithms first, then expand features

**Timeline**: 10 weeks 
**Resources**: Core NenDB team + algorithm specialists
**Risk Level**: MEDIUM (manageable technical challenges)
