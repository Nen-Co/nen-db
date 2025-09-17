# 🚀 NenDB - AI-Native Graph Database

> **Lightning-fast graph database built with Data-Oriented Design (DOD) for AI workloads** ⚡

[![Zig](https://img.shields.io/badge/Zig-0.15.1-F7A41D)](https://ziglang.org/)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)
[![Version](https://img.shields.io/badge/Version-v0.2.0--beta-green.svg)](https://github.com/Nen-Co/nen-db/releases)
[![Docker](https://img.shields.io/badge/Docker-GHCR-blue.svg)](https://ghcr.io/nen-co/nendb)
[![DOD](https://img.shields.io/badge/Architecture-Data--Oriented--Design-FF6B6B)](docs/DATA_ORIENTED_DESIGN.md)

## 🎯 What is NenDB?

NenDB is a **Data-Oriented Design (DOD) graph database** built specifically for AI applications. Using Struct of Arrays (SoA) layout, component-based architecture, and SIMD optimization, it delivers:

- 🧠 **AI-Native Design**: Optimized for graph reasoning and AI workloads
- ⚡ **Data-Oriented Design**: SoA layout for maximum cache efficiency
- 🚀 **SIMD Optimization**: Vectorized operations for peak performance
- 🧩 **Component System**: Flexible entity-component architecture
- 🛡️ **Crash Safe**: WAL-based durability with point-in-time recovery
- 🔧 **Zero Dependencies**: Self-contained with minimal external requirements

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

### 🎯 **DOD Demo**
Experience the power of Data-Oriented Design:

```bash
# Run the DOD performance demo
zig build dod-demo
```

This demo showcases:
- **SoA Performance**: Struct of Arrays vs Array of Structs
- **SIMD Filtering**: Vectorized node and edge filtering
- **Component System**: Entity-component architecture
- **Memory Statistics**: Cache efficiency and utilization

### 📦 **Installation**

**Linux (x86_64)**
```bash
curl -fsSL https://github.com/Nen-Co/nen-db/releases/download/v0.2.0-beta-fixed/nen-v0.2.0-beta-fixed-linux-x86_64.tar.gz | tar -xz
```

**Windows PowerShell**
```powershell
Invoke-WebRequest -Uri "https://github.com/Nen-Co/nen-db/releases/download/v0.2.0-beta-fixed/nen-v0.2.0-beta-fixed-windows-x86_64.zip" -OutFile "nen-windows.zip"
Expand-Archive -Path "nen-windows.zip" -DestinationPath "."
```

**macOS (Coming Soon)**
```bash
# macOS builds temporarily unavailable due to GitHub service issues
# Use Docker or build from source instead
```

**🐳 Docker (Recommended)**
```bash
# Pull and run with HTTP server on port 8080
docker run --rm -p 8080:8080 --name nendb \
  -v $(pwd)/data:/data \
  ghcr.io/nen-co/nendb:latest
```

**📦 Generated Binaries**
After building with specific targets, you'll find:
- `zig-out/bin/nendb` - Executable for the current platform
- `zig-out/bin/nendb-server` - HTTP server for the current platform

**For cross-compilation, use:**
- `zig build -Dtarget=x86_64-linux-gnu` → Linux x86_64 binary
- `zig build -Dtarget=x86_64-macos-none` → macOS Intel binary (no libc)  
- `zig build -Dtarget=aarch64-macos-none` → macOS Apple Silicon binary (no libc)
- `zig build -Dtarget=x86_64-windows-gnu` → Windows x86_64 binary

**✅ Working Releases:** Download links are now working! The v0.2.0-beta-fixed release includes working binaries.

### 🎉 **Release System Status**
- ✅ **Linux x86_64**: Working download links
- ✅ **Windows x86_64**: Working download links  
- ⚠️ **macOS**: Temporarily unavailable due to GitHub service issues
- ✅ **Automated Releases**: GitHub Actions workflows functional
- ✅ **Asset Upload**: Proper binary packaging and distribution
- ✅ **Version Management**: Consistent versioning across platforms

### 🏃 **Running NenDB**

**Start HTTP Server**
```bash
./zig-out/bin/nendb-server
# Server will be available at http://localhost:8080
```

**CLI Commands**
```bash
# Check version and help
nendb --version
nendb help

# Run interactive demo
nendb demo

# Initialize a new database
nendb init ./my-database

# Start interactive server (runs continuously)
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
- 🐍 **Python Client**: [https://nen-co.github.io/docs/nendb-python-driver/](https://nen-co.github.io/docs/nendb-python-driver/)
- 🐳 **Docker Guide**: [DOCKER.md](DOCKER.md)

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

### 🎯 **v0.2.0-beta (Current)**
- ✅ Static memory graph database
- ✅ Data-Oriented Design (DOD) architecture
- ✅ Cross-platform releases (Linux, macOS, Windows)
- ✅ Working download links for all platforms
- ✅ TCP server implementation
- ✅ Basic graph algorithms
- ✅ WAL persistence
- ✅ CLI interface
- ✅ WebAssembly support

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
