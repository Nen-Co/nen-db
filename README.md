# 🚀 NenDB - AI-Native Graph Database

> **Lightning-fast graph database built with Zig for AI workloads** ⚡

[![Zig](https://img.shields.io/badge/Zig-0.14.1-F7A41D)](https://ziglang.org/)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Version](https://img.shields.io/badge/Version-v0.1.0--beta-green.svg)](https://github.com/Nen-Co/nen-db/releases)
[![Docker](https://img.shields.io/badge/Docker-GHCR-blue.svg)](https://ghcr.io/nen-co/nendb)

## 🎯 What is NenDB?

NenDB is a **static memory graph database** designed specifically for AI applications. Built with Zig for maximum performance and predictable memory usage, it provides:

- 🧠 **AI-Native Design**: Optimized for graph reasoning and AI workloads
- ⚡ **Static Memory**: Zero garbage collection overhead
- 🚀 **Lightning Fast**: Built with Zig for maximum performance
- 🛡️ **Crash Safe**: WAL-based durability with point-in-time recovery
- 🔧 **Zero Dependencies**: Self-contained with minimal external requirements

## ✨ Key Features

### 🎨 **Core Capabilities**
- **Static Memory Pools**: Predictable performance with configurable memory limits
- **Write-Ahead Logging**: Crash-safe persistence with point-in-time recovery
- **Graph Algorithms**: BFS, Dijkstra, PageRank, and Community Detection
- **HTTP API**: RESTful interface using nen-net networking framework
- **CLI Interface**: Command-line tool for database management

### 🚀 **Performance Features**
- **Memory Pools**: Static allocation for zero GC overhead
- **Predictable Latency**: Consistent response times under load
- **Efficient Storage**: Optimized data structures for graph operations
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

**Linux (x86_64)**
```bash
curl -fsSL https://github.com/Nen-Co/nen-db/releases/latest/download/nen-linux-x86_64.tar.gz | tar -xz
```

**macOS (Intel)**
```bash
curl -fsSL https://github.com/Nen-Co/nen-db/releases/latest/download/nen-macos-x86_64.tar.gz | tar -xz
```

**macOS (Apple Silicon - M1/M2)**
```bash
curl -fsSL https://github.com/Nen-Co/nen-db/releases/latest/download/nen-macos-aarch64.tar.gz | tar -xz
```

**Windows PowerShell**
```powershell
Invoke-WebRequest -Uri "https://github.com/Nen-Co/nen-db/releases/latest/download/nen-windows-x86_64.zip" -OutFile "nen-windows.zip"
Expand-Archive -Path "nen-windows.zip" -DestinationPath "."
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

**💡 Note:** The installation URLs in the Quick Start section will be updated when releases are published with the correct binary names for each platform.

### 🏃 **Running NenDB**

**Start HTTP Server**
```bash
./zig-out/bin/nendb-server
# Server will be available at http://localhost:8080
```

**CLI Commands**
```bash
# Check version
./zig-out/bin/nendb --version

# Start TCP server
./zig-out/bin/nendb serve
```

### 🧪 **Test the Server**

```bash
# Health check
curl http://localhost:8080/health

# Graph statistics
curl http://localhost:8080/graph/stats
```

## 🏗️ Building from Source

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

### 🎯 **v0.1.0-beta (Current)**
- ✅ Static memory graph database
- ✅ HTTP API server
- ✅ Basic graph algorithms
- ✅ WAL persistence
- ✅ CLI interface

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

See our [Contributing Guide](CONTRIBUTING.md) for detailed information.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

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

**Ready to build AI-native graph applications?** 🚀 [Get started now!](https://nen-co.github.io/docs/nendb/)