# 🚀 NenDB - AI-Native Graph Database

> **Lightning-fast graph database built with Data-Oriented Design (DOD) for AI workloads** ⚡

[![Zig](https://img.shields.io/badge/Zig-0.15.1-F7A41D)](https://ziglang.org/)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
[![Version](https://img.shields.io/badge/Version-v0.2.1--beta-green.svg)](https://github.com/Nen-Co/nen-db/releases)
[![Docker](https://img.shields.io/badge/Docker-GHCR-blue.svg)](https://ghcr.io/nen-co/nendb)
[![DOD](https://img.shields.io/badge/Architecture-Data--Oriented--Design-FF6B6B)](docs/DATA_ORIENTED_DESIGN.md)

## 🎯 What is NenDB?

NenDB is a **dual-architecture graph database** built specifically for AI applications. We provide both **embedded** and **distributed** options to serve different use cases and market segments.

### 🏗️ **Dual Architecture Strategy**

#### **Embedded NenDB** 🖥️ (Primary Focus)
- **Target**: Single-user applications, AI/ML workloads, desktop apps
- **Use Cases**: Data science, research, personal projects, edge computing
- **Advantages**: Zero dependencies, instant startup, predictable performance
- **Examples**: Jupyter notebooks, desktop apps, embedded systems

#### **Distributed NenDB** 🌐 (Framework Only)
- **Target**: Multi-user applications, enterprise workloads, cloud services (planned)
- **Use Cases**: Social networks, recommendation systems, real-time analytics (planned)
- **Advantages**: Horizontal scaling, high availability, fault tolerance (planned)
- **Examples**: Web applications, microservices, cloud platforms (planned)
- **Status**: Framework exists, implementation in progress

### 🚀 **Core Technology**

Using Data-Oriented Design (DOD), Struct of Arrays (SoA) layout, component-based architecture, and SIMD optimization, NenDB delivers:

- 🧠 **AI-Native Design**: Optimized for graph reasoning and AI workloads
- ⚡ **Data-Oriented Design**: SoA layout for maximum cache efficiency
- 🚀 **SIMD Optimization**: Vectorized operations for peak performance
- 🧩 **Component System**: Flexible entity-component architecture
- 🛡️ **Crash Safe**: WAL-based durability with point-in-time recovery
- 🔧 **Zero Dependencies**: Self-contained with minimal external requirements

### 🎯 **Why We're Focusing on Embedded First**

1. **Solid Foundation**: Embedded is simpler, easier to get right
2. **Market Validation**: Faster developer adoption, AI/ML focus
3. **Technical Benefits**: Zero dependencies, predictable performance
4. **Business Strategy**: Community building drives future enterprise adoption

> **📖 [Read our full roadmap →](ROADMAP.md)** | **🏗️ [Architecture overview →](docs/ARCHITECTURE.md)** | **📊 [Current status →](CURRENT_STATUS.md)** | **📚 [All documentation →](DOCUMENTATION.md)**



**Current NenDB Advantages:**
- **🧠 AI-Native**: Built specifically for AI/ML workloads
- **🔧 Zero Dependencies**: Easy deployment and distribution
- **⚡ Data-Oriented Design**: SoA layout for performance
- **🚧 Multi-Process**: Currently in development
- **🚧 Distributed**: Framework exists, implementation in progress

**Note**: Performance claims will be validated through benchmarks once implementation is complete.

## 🛠️ **Current Implementation Status**

### **✅ Completed (Embedded Focus)**
- **Core Engine**: Graph operations, memory management, basic concurrency
- **AI/ML Framework**: Vector operations structure, knowledge graph parsing
- **Memory Layout**: SoA implementation, basic memory pools
- **Python Driver**: Full-featured client with `pip install nendb`
- **Examples**: Desktop apps, data science workflows
- **Documentation**: Comprehensive guides and API docs

### **🟡 In Progress (Embedded Enhancement)**
- **Multi-Process Support**: File locking, shared memory coordination
- **Production WAL**: Complete write-ahead logging implementation
- **Memory Prediction**: Advanced allocation algorithms
- **Performance Optimization**: SIMD operations, cache optimization

### **🚧 Framework Only (Distributed)**
- **Basic Structure**: HTTP API framework, cluster management classes
- **Consensus**: Placeholder for Raft/PBFT (not implemented)
- **Networking**: Basic server setup (no real communication)
- **Replication**: Framework exists (no actual replication)

### **🔴 Planned (Future Phases)**
- **Real Distributed**: Complete consensus, networking, replication
- **Enterprise Features**: Security, compliance, advanced clustering
- **Cloud Services**: Managed NenDB, auto-scaling

> **📖 [See detailed roadmap →](ROADMAP.md)**

## ✨ Key Features

### 🎨 **Core Capabilities**
- **Data-Oriented Design**: Struct of Arrays (SoA) layout for maximum performance
- **Component System**: Entity-component architecture for flexible data modeling
- **SIMD Operations**: Vectorized processing for peak throughput
- **Static Memory Pools**: Predictable performance with configurable memory limits
- **Write-Ahead Logging**: Crash-safe persistence with point-in-time recovery
- **Graph Algorithms**: BFS, Dijkstra, PageRank, and Community Detection
- **HTTP API**: RESTful interface using nen-net networking framework
- **CLI Interface**: Command-line tool for database management

### 🚀 **Performance Features**
- **Cache Locality**: SoA layout optimizes memory access patterns
- **SIMD Optimization**: Vectorized operations on aligned data structures
- **Hot/Cold Separation**: Frequently accessed data separated from cold data
- **Memory Pools**: Static allocation for zero GC overhead
- **Predictable Latency**: Consistent response times under load
- **Efficient Storage**: DOD-optimized data structures for graph operations
- **Cross-Platform**: Linux, macOS, and Windows support

### 🔌 **API Endpoints**
- `GET /health` - Server health check
- `GET /graph/stats` - Graph statistics
- `POST /graph/algorithms/bfs` - Breadth-first search
- `POST /graph/algorithms/dijkstra` - Shortest path
- `POST /graph/algorithms/pagerank` - PageRank centrality
- `POST /graph/algorithms/community` - Community detection

## 🚀 Quick Start

### 📦 **Installation**

**🐍 Python Client (Easiest)**
```bash
# Install the Python client from PyPI
pip install nendb

# Start using immediately
python -c "from nendb import NenDBClient; client = NenDBClient('http://localhost:8080'); print(client.health())"
```

**🍺 Homebrew (macOS)**
```bash
# Add the NenDB tap
brew tap nen-co/nendb

# Install NenDB server
brew install nendb

# Start the server
nendb-server serve

# Or use the core binary
nendb-core --version
```

**📦 Binary Releases (Recommended)**
```bash
# Download pre-built binaries from GitHub Releases
# Visit: https://github.com/Nen-Co/nen-db/releases

# For Linux x86_64
wget https://github.com/Nen-Co/nen-db/releases/download/v0.2.1-beta/nendb-linux-x86_64
chmod +x nendb-linux-x86_64
./nendb-linux-x86_64 --version

# For macOS (Intel)
wget https://github.com/Nen-Co/nen-db/releases/download/v0.2.1-beta/nendb-macos-x86_64
chmod +x nendb-macos-x86_64
./nendb-macos-x86_64 --version

# For macOS (Apple Silicon)
wget https://github.com/Nen-Co/nen-db/releases/download/v0.2.1-beta/nendb-macos-aarch64
chmod +x nendb-macos-aarch64
./nendb-macos-aarch64 --version

# For Windows x86_64
wget https://github.com/Nen-Co/nen-db/releases/download/v0.2.1-beta/nendb-windows-x86_64.exe
nendb-windows-x86_64.exe --version
```

**🔨 Build from Source**
```bash
# Clone the repository
git clone https://github.com/Nen-Co/nen-db.git
cd nen-db

# Build the project
zig build

# Run the executable
./zig-out/bin/nendb --version
```

**🐳 Docker (Alternative)**
```bash
# Pull and run with HTTP server on port 8080
docker run --rm -p 8080:8080 --name nendb \
  -v $(pwd)/data:/data \
  ghcr.io/nen-co/nendb:latest
```

### 🏃 **Running NenDB**

**🐍 Python Usage (With pip install)**
```python
from nendb import NenDBClient

# Connect to NenDB server
client = NenDBClient('http://localhost:8080')

# Check server health
print(client.health())
# Output: {'status': 'healthy', 'service': 'nendb', 'version': 'v0.2.1-beta'}

# Get graph statistics
stats = client.get_stats()
print(f"Nodes: {stats['nodes']}, Edges: {stats['edges']}")

# Run graph algorithms
bfs_result = client.bfs(source=1, target=2)
dijkstra_result = client.dijkstra(source=1, target=2)
pagerank_result = client.pagerank()
community_result = client.community_detection()

print("BFS Result:", bfs_result)
print("Dijkstra Result:", dijkstra_result)
print("PageRank Result:", pagerank_result)
print("Community Detection Result:", community_result)
```

**🚀 Start HTTP Server**
```bash
# Using Homebrew (macOS)
nendb-server serve
# Server will be available at http://localhost:8080

# Using binary release
./nendb-linux-x86_64 serve
# Server will be available at http://localhost:8080

# Using built from source
./zig-out/bin/nendb serve
# Server will be available at http://localhost:8080
```

**💻 CLI Commands**
```bash
# Check version and help (Homebrew)
nendb-server --version
nendb-server help

# Run interactive demo (Homebrew)
nendb-server demo

# Initialize a new database (Homebrew)
nendb-server init ./my-database

# Start interactive server (runs continuously)
nendb-server serve

# Or using built from source
nendb --version
nendb help
nendb demo
nendb init ./my-database
nendb serve
```

**Installation for Global Access**
```bash
# After building, create symlink for global access
mkdir -p ~/.local/bin
ln -sf $(pwd)/zig-out/bin/nendb ~/.local/bin/nendb

# Add to PATH (add to ~/.bashrc or ~/.zshrc)
export PATH="$HOME/.local/bin:$PATH"
```

**Server Features**
- **Interactive Server**: Runs continuously with real-time status monitoring
- **HTTP Server**: Available at http://localhost:8080
- **Status Updates**: Shows database statistics every 5 seconds
- **Clean Operation**: No automatic data insertion - maintains database state
- **Easy Control**: Press Ctrl+C to stop the server

### 🧪 **Test the Server**

```bash
# Health check
curl http://localhost:8080/health

# Graph statistics
curl http://localhost:8080/graph/stats
```

## � WebAssembly (WASM) Build

NenDB compiles to a lightweight **37KB WASM module** for embedded usage in browsers and JavaScript environments:

### 📦 **Quick Start**
```html
<script type="module">
    import NenDB from 'https://github.com/Nen-Co/nen-db/releases/download/v0.2.0-beta/nendb-wasm.js';
    
    const db = await NenDB.loadFromURL('https://github.com/Nen-Co/nen-db/releases/download/v0.2.0-beta/nendb-wasm.wasm');
    
    // Add graph data
    const node1 = db.addNode(100);
    const node2 = db.addNode(200);
    const edge = db.addEdge(100, 200, 1.5);
    
    console.log('Memory usage:', db.getMemoryUsage(), 'bytes');
    db.destroy();
</script>
```

### 🏗️ **Build WASM**
```bash
# Build WASM module
zig build wasm

# Output: zig-out/bin/nendb-wasm.wasm (~37KB)
```

### ✨ **Features**
- **🪶 Lightweight**: Only ~37KB WASM file
- **⚡ Embedded**: SQLite-like simplicity for graph data
- **🔧 Zero Dependencies**: Pure Zig compiled to clean WASM
- **🌐 Universal**: Browser, Node.js, Deno, Bun support
- **🛡️ Static Memory**: Predictable performance in constrained environments

For detailed usage examples, see [wasm/README.md](wasm/README.md).

## �🏗️ Building from Source

### 📋 **Prerequisites**
- [Zig 0.14.1](https://ziglang.org/download/) or later
- Git

### 🔨 **Build Steps**
```bash
# Clone the repository
git clone https://github.com/Nen-Co/nen-db.git
cd nen-db

# Build the project
zig build

# Run tests
zig build test

# Build optimized release
zig build -Doptimize=ReleaseSafe

# Build WASM module (~37KB)
zig build wasm

# Build for all target platforms (Linux, macOS Intel/ARM, Windows)
zig build cross-compile

# Or build for specific targets:
zig build -Dtarget=x86_64-linux-gnu    # Linux x86_64
zig build -Dtarget=x86_64-macos-none   # macOS Intel (no libc)
zig build -Dtarget=aarch64-macos-none  # macOS Apple Silicon (no libc)
zig build -Dtarget=x86_64-windows-gnu  # Windows x86_64
```

## 🐳 Docker Support

NenDB provides official Docker images via GitHub Container Registry (GHCR):

- **Latest**: `ghcr.io/nen-co/nendb:latest`
- **Versioned**: `ghcr.io/nen-co/nendb:v0.1.0-beta`
- **Simple variant**: `ghcr.io/nen-co/nendb:simple-latest`

See [DOCKER.md](DOCKER.md) for comprehensive Docker usage instructions.

## 📚 Documentation

- 🌐 **Website**: [https://nen-co.github.io/docs/nendb/](https://nen-co.github.io/docs/nendb/)
- 📖 **API Reference**: [https://nen-co.github.io/docs/nendb/api/](https://nen-co.github.io/docs/nendb/api/)
- 🐍 **Python Client**: [PyPI Package](https://pypi.org/project/nendb/) | [GitHub](https://github.com/Nen-Co/nendb-python)
- 🐳 **Docker Guide**: [DOCKER.md](DOCKER.md)
- 🛠️ **Troubleshooting**: [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md)

### 🐍 **Python Driver**

The official Python client is available on PyPI and provides a simple interface to NenDB:

```bash
# Install from PyPI
pip install nendb

# Or install from source
git clone https://github.com/Nen-Co/nendb-python.git
cd nendb-python
pip install -e .
```

**Features:**
- ✅ **Easy Installation**: `pip install nendb`
- ✅ **Simple API**: Intuitive Python interface
- ✅ **Graph Algorithms**: BFS, Dijkstra, PageRank, Community Detection
- ✅ **Error Handling**: Comprehensive exception handling
- ✅ **Type Hints**: Full type annotation support
- ✅ **Async Support**: Asynchronous operations (coming soon)

## 🧪 Testing

```bash
# Run all tests
zig build test

# Run specific test categories
zig build test-unit
zig build test-integration
zig build test-performance

# Run with coverage
zig build test --summary all
```

## 🚀 Performance

NenDB is designed for high-performance graph operations:

- **Static Memory**: No dynamic allocations during runtime
- **Predictable Latency**: Consistent response times under load
- **Efficient Algorithms**: Optimized implementations of graph algorithms
- **Zero GC Overhead**: Static memory pools eliminate garbage collection

## 🔮 Roadmap

### 🎯 **v0.2.1-beta (Current)**
- ✅ Static memory graph database
- ✅ Data-Oriented Design (DOD) architecture
- ✅ Cross-platform releases (Linux, macOS, Windows)
- ✅ Interactive server with smart status updates
- ✅ Basic graph algorithms
- ✅ WAL persistence
- ✅ CLI interface with global access
- ✅ WebAssembly support
- ✅ Optimized server performance

### 🚀 **Future Releases**
- 🔄 Enhanced graph algorithms
- 🔍 Cypher-like query language
- 🧠 Vector similarity search
- 📊 GraphRAG support
- ⚡ Performance optimizations
- 🌐 Distributed clustering

## 🤝 Contributing

We welcome contributions! 🎉

1. 🍴 Fork the repository
2. 🌿 Create a feature branch (`git checkout -b feature/amazing-feature`)
3. 💾 Commit your changes (`git commit -m 'Add amazing feature'`)
4. 📤 Push to the branch (`git push origin feature/amazing-feature`)
5. 🔄 Open a Pull Request

See our [Contributing Guide](https://github.com/Nen-Co/nen-db/blob/main/docs/deployment/CONTRIBUTING.md) for detailed information.

## 📄 License

This project is licensed under the APACHE 2.0 License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

- 🐛 **Issues**: [GitHub Issues](https://github.com/Nen-Co/nen-db/issues)
- 📖 **Documentation**: [https://nen-co.github.io/docs/nendb/](https://nen-co.github.io/docs/nendb/)
- 💬 **Community**: [Discord](https://discord.gg/nen-co)

## 🙏 Acknowledgments

- Built with [Zig](https://ziglang.org/) for maximum performance
- Networking powered by [nen-net](https://github.com/Nen-Co/nen-net)
- I/O operations using [nen-io](https://github.com/Nen-Co/nen-io)
- JSON handling via [nen-json](https://github.com/Nen-Co/nen-json)

---

**Ready to build AI-native graph applications?** 🚀 [Get started now!](https://www.nenco.co/docs)
