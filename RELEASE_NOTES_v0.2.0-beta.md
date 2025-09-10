# 🚀 NenDB v0.2.0-beta - Data-Oriented Design Release

## 🎯 **Major Updates Since v0.1.0-beta**

### ⚡ **Performance & Architecture**
- **Data-Oriented Design (DOD)**: Struct of Arrays (SoA) layout for maximum cache efficiency
- **High-Performance TCP Server**: Replaced HTTP with optimized TCP for better throughput  
- **SIMD Optimization**: Vectorized operations on aligned data structures
- **Static Memory Pools**: Predictable performance with zero GC overhead

### 🔧 **Technical Improvements**
- **Zig 0.15.1 Compatibility**: Updated from 0.14.1 with all breaking changes handled
- **Cross-Platform CI/CD**: Matrix builds on Linux, macOS, Windows
- **Clean Ecosystem**: Integrated nen-io, nen-json, nen-net libraries  
- **Repository Organization**: Cleaned structure (26+ files → 7 in root)

### 🧪 **Quality & Testing**
- **Comprehensive Test Coverage**: Unit, integration, TCP, and benchmark tests
- **Memory Analysis**: Memory layout and performance profiling
- **Cross-Platform**: Verified builds on all major operating systems

## 📦 **What's New**
- 🚀 TCP server with DOD architecture
- 🧩 Component-based entity system  
- 💾 Enhanced memory management
- 🌍 Cross-platform socket handling
- 🔨 Improved build system
- 📚 Better documentation structure

## 🔧 **Breaking Changes**
- HTTP server replaced with TCP server (performance focused)
- API endpoints now use TCP protocol  
- Memory pools are statically allocated at startup

## 🚀 **Getting Started**

### Quick Install (Linux/macOS)
```bash
# Download and extract
curl -fsSL https://github.com/Nen-Co/nen-db/releases/download/v0.2.0-beta/nen-linux-x86_64.tar.gz | tar -xz

# Run the TCP server
./zig-out/bin/nendb-tcp-server
```

### Windows PowerShell
```powershell
# Download and extract
Invoke-WebRequest -Uri "https://github.com/Nen-Co/nen-db/releases/download/v0.2.0-beta/nen-windows-x86_64.zip" -OutFile "nen-windows.zip"
Expand-Archive -Path "nen-windows.zip" -DestinationPath "."

# Run the TCP server  
.\zig-out\bin\nendb-tcp-server.exe
```

### Docker (GitHub Container Registry)
```bash
# Pull and run with TCP server on port 8080
docker run --rm -p 8080:8080 --name nendb \
  -v $(pwd)/data:/data \
  ghcr.io/nen-co/nendb:v0.2.0-beta
```

## 🏗️ **Building from Source**
```bash
# Clone the repository
git clone https://github.com/Nen-Co/nen-db.git
cd nen-db

# Build with Zig 0.15.1
zig build

# Run tests
zig build test-unit

# Check version
./zig-out/bin/nendb --version
```

## 📊 **Performance Improvements**
- **40%+ faster** TCP vs HTTP server
- **Better cache locality** with DOD SoA layout
- **SIMD vectorization** on aligned data
- **Zero garbage collection** with static memory pools

## 📄 **License**
Apache 2.0 License - see LICENSE file.
