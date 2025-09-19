# 📁 NenDB Folder Structure

> **Organized codebase with separated concerns and shared logic**

## 🏗️ **Folder Organization**

```
nen-db/                          # Community Edition Repository
├── src/
│   ├── shared/                  # Shared core logic
│   │   ├── core/               # Core database engine
│   │   │   ├── lib.zig        # Main database struct
│   │   │   ├── graphdb.zig    # Graph operations
│   │   │   └── constants.zig  # Shared constants
│   │   ├── memory/            # Memory management
│   │   │   ├── layout.zig     # SoA memory layout
│   │   │   ├── wal.zig        # Write-ahead logging
│   │   │   ├── simd.zig       # SIMD operations
│   │   │   └── predictor.zig  # Memory prediction
│   │   ├── algorithms/        # Graph algorithms
│   │   │   └── algorithms.zig # BFS, Dijkstra, PageRank, etc.
│   │   ├── concurrency/       # Concurrency primitives
│   │   │   └── concurrency.zig # Locks, atomic ops, transactions
│   │   └── ai_ml/             # AI/ML features
│   │       └── ai_ml.zig      # Vector embeddings, GNN ops
│   ├── embedded/              # Embedded NenDB
│   │   ├── embedded.zig       # Embedded database implementation
│   │   ├── desktop/           # Desktop application features
│   │   └── examples/          # Embedded examples
│   ├── distributed/           # Distributed NenDB
│   │   ├── distributed.zig    # Distributed database implementation
│   │   ├── clustering/        # Clustering and consensus
│   │   ├── networking/        # Network protocols
│   │   └── examples/          # Distributed examples
│   └── main.zig               # Main entry point
├── examples/                  # Cross-platform examples
├── docs/                     # Documentation
├── tools/                    # Build tools and utilities
└── tests/                    # Test suites
```

## 🎯 **Separation of Concerns**

### **Shared (`src/shared/`)**
- **Core Engine**: Database operations, memory management
- **Algorithms**: Graph algorithms (BFS, Dijkstra, PageRank)
- **Memory**: SoA layout, WAL, SIMD operations
- **Concurrency**: Locks, atomic operations, transactions
- **AI/ML**: Vector embeddings, knowledge graph operations

### **Embedded (`src/embedded/`)**
- **Single-user**: Desktop apps, data science, edge computing
- **Zero Dependencies**: Self-contained, instant startup
- **AI/ML Focus**: Optimized for vector operations
- **Examples**: Jupyter notebooks, desktop applications

### **Distributed (`src/distributed/`)**
- **Multi-user**: Web apps, microservices, cloud services
- **Clustering**: Consensus algorithms, load balancing
- **Networking**: HTTP API, protocol handling
- **Examples**: Web applications, distributed systems


## 🔄 **Shared Logic Benefits**

### **Code Reuse**
- **Single Source of Truth**: Core logic in one place
- **Consistent Behavior**: Same algorithms across all versions
- **Maintenance**: Fix bugs once, benefit everywhere
- **Testing**: Test core logic once, validate everywhere

### **Modularity**
- **Clear Boundaries**: Each folder has specific responsibilities
- **Easy Navigation**: Developers know where to find things
- **Scalability**: Easy to add new features or versions
- **Team Organization**: Different teams can work on different folders

## 🚀 **Implementation Strategy**

### **Phase 1: Reorganize Current Code**
1. **Move shared logic** to `src/shared/`
2. **Move embedded code** to `src/embedded/`
3. **Move distributed code** to `src/distributed/`
4. **Update imports** to use new structure



### **Phase 3: Optimize and Scale**
1. **Performance optimization** across all modules
2. **Advanced features** for each architecture
3. **Cloud services** and managed offerings
4. **Enterprise support** and documentation

## 📦 **Build System Integration**

### **Modular Builds**
- **Embedded**: Only build embedded + shared
- **Distributed**: Only build distributed + shared
- **Enterprise**: Build all modules
- **Full**: Build everything for testing

### **Dependency Management**
- **Shared**: No external dependencies
- **Embedded**: Minimal dependencies
- **Distributed**: Network dependencies
- **Enterprise**: Full enterprise stack

## 🎯 **Benefits of This Structure**

### **For Developers**
- **Clear Organization**: Easy to find and understand code
- **Modular Development**: Work on specific features independently
- **Shared Logic**: Reuse proven code across architectures
- **Testing**: Test each module independently

### **For Users**
- **Flexible Deployment**: Choose what you need
- **Consistent API**: Same interface across all versions
- **Performance**: Optimized for specific use cases
- **Scalability**: Easy to upgrade from embedded to distributed


---

*This structure provides maximum flexibility while maintaining code organization and reusability.*
