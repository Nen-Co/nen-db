#!/bin/bash
# Simple cross-compilation script for NenDB using Zig's built-in capabilities
# Zig makes cross-compilation trivial - no complex toolchain setup needed!

set -e

# Colors for output  
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

print_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }

# Zig's amazing cross-compilation targets
TARGETS=(
    "x86_64-linux-gnu"      # Linux x64
    "aarch64-linux-gnu"     # Linux ARM64
    "x86_64-macos"          # macOS Intel
    "aarch64-macos"         # macOS Apple Silicon  
    "x86_64-windows-gnu"    # Windows x64
)

print_info "🚀 NenDB Cross-Compilation using Zig's built-in capabilities"
print_info "Zig version: $(zig version)"

# Clean previous builds
rm -rf zig-out .zig-cache

# Build for each target - Zig handles all the complexity!
for target in "${TARGETS[@]}"; do
    print_info "Building for $target..."
    
    # Zig's cross-compilation is this simple:
    zig build -Dtarget=$target --release=safe
    
    # Rename binaries to include target
    if [[ -d "zig-out/bin" ]]; then
        mkdir -p "dist/$target"
        cp -r zig-out/bin/* "dist/$target/"
        print_success "✓ Built for $target"
    fi
done

# Test on native platform
print_info "Running tests on native platform..."
zig build test-unit
zig build test-tcp

print_success "🎉 Cross-compilation completed!"
print_info "Binaries available in dist/ directory for all platforms"
ls -la dist/
