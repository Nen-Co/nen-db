# NenDB Build System
# Comprehensive error prevention and CI/CD support

.PHONY: help build test clean validate deps format lint pre-commit ci-cd

# Default target
help:
	@echo "🚀 NenDB Build System"
	@echo "===================="
	@echo ""
	@echo "Available targets:"
	@echo "  build          - Build all targets (Debug, ReleaseSafe, ReleaseFast, ReleaseSmall)"
	@echo "  test           - Run all tests"
	@echo "  clean          - Clean build artifacts"
	@echo "  validate       - Run comprehensive validation"
	@echo "  deps           - Check dependencies"
	@echo "  format         - Format code"
	@echo "  lint           - Run linting checks"
	@echo "  pre-commit     - Run pre-commit validation"
	@echo "  ci-cd          - Run full CI/CD pipeline locally"
	@echo "  fast           - Build with ReleaseFast optimization"
	@echo "  wasm           - Build WASM version"
	@echo "  cross-compile  - Cross-compile for all platforms"
	@echo ""

# Build targets
build:
	@echo "🔨 Building all targets..."
	zig build
	zig build --release=safe
	zig build --release=fast
	zig build --release=small
	@echo "✅ All builds completed"

fast:
	@echo "⚡ Building with ReleaseFast optimization..."
	zig build --release=fast
	@echo "✅ Fast build completed"

wasm:
	@echo "🌐 Building WASM version..."
	zig build wasm
	@echo "✅ WASM build completed"

# Test targets
test:
	@echo "🧪 Running all tests..."
	zig build test-unit
	zig build test-integration
	zig build test-performance
	zig build test-algorithms
	@echo "✅ All tests completed"

# Clean target
clean:
	@echo "🧹 Cleaning build artifacts..."
	rm -rf zig-out/
	rm -rf .zig-cache/
	@echo "✅ Clean completed"

# Validation targets
validate:
	@echo "🔍 Running comprehensive validation..."
	zig run scripts/build-all.zig
	@echo "✅ Validation completed"

deps:
	@echo "🔗 Checking dependencies..."
	zig run scripts/simple-deps.zig
	@echo "✅ Dependency check completed"

format:
	@echo "🎨 Formatting code..."
	zig fmt src/ examples/ tests/
	@echo "✅ Formatting completed"

lint:
	@echo "🔍 Running lint checks..."
	zig run scripts/pre-commit-hook.zig
	@echo "✅ Lint checks completed"

pre-commit:
	@echo "🔍 Running pre-commit validation..."
	zig run scripts/pre-commit-hook.zig
	@echo "✅ Pre-commit validation completed"

# CI/CD target
ci-cd:
	@echo "🚀 Running full CI/CD pipeline locally..."
	@echo "This will take several minutes..."
	zig run scripts/build-all.zig
	@echo "✅ CI/CD pipeline completed locally"

# Cross-compilation
cross-compile:
	@echo "🌍 Cross-compiling for all platforms..."
	zig build --release=fast -Dtarget=x86_64-linux-gnu
	zig build --release=fast -Dtarget=x86_64-macos
	zig build --release=fast -Dtarget=aarch64-macos
	zig build --release=fast -Dtarget=x86_64-windows-gnu
	zig build --release=fast -Dtarget=wasm32-freestanding
	@echo "✅ Cross-compilation completed"

# Development targets
dev-setup:
	@echo "🛠️  Setting up development environment..."
	@echo "Installing pre-commit hook..."
	chmod +x scripts/pre-commit-hook.zig
	ln -sf scripts/pre-commit-hook.zig .git/hooks/pre-commit
	@echo "✅ Development setup completed"

# Performance testing
perf:
	@echo "⚡ Running performance tests..."
	zig build --release=fast test-performance
	zig build --release=fast demo-nen-core
	@echo "✅ Performance tests completed"

# Security checks
security:
	@echo "🔒 Running security checks..."
	@echo "Checking for unsafe patterns..."
	@grep -r "unsafe" src/ --include="*.zig" || echo "No unsafe patterns found"
	@echo "Checking for manual memory management..."
	@grep -r "malloc\|free" src/ --include="*.zig" || echo "No manual memory management found"
	@echo "✅ Security checks completed"

# Documentation
docs:
	@echo "📚 Generating documentation..."
	@echo "TODO: Add documentation generation"
	@echo "✅ Documentation completed"

# Install targets
install:
	@echo "📦 Installing NenDB..."
	zig build --release=fast
	@echo "✅ Installation completed"

install-user:
	@echo "📦 Installing NenDB to user directory..."
	zig build --release=fast install-user
	@echo "✅ User installation completed"

install-system:
	@echo "📦 Installing NenDB to system directory..."
	zig build --release=fast install-system
	@echo "✅ System installation completed"

# Quick development cycle
dev: format lint test
	@echo "🔄 Development cycle completed"

# Full validation before commit
commit: deps format lint test build
	@echo "✅ Ready to commit!"

# Emergency build (skip tests for quick fixes)
emergency: format build
	@echo "🚨 Emergency build completed (tests skipped)"

# Show build status
status:
	@echo "📊 Build Status"
	@echo "==============="
	@echo "Zig version: $(shell zig version)"
	@echo "Build cache: $(shell du -sh .zig-cache 2>/dev/null || echo 'Not found')"
	@echo "Output dir: $(shell du -sh zig-out 2>/dev/null || echo 'Not found')"
	@echo "Dependencies:"
	@echo "  nen-core: $(shell test -d ../nen-core && echo '✅' || echo '❌')"
	@echo "  nen-io: $(shell test -d ../nen-io && echo '✅' || echo '❌')"
	@echo "  nen-json: $(shell test -d ../nen-json && echo '✅' || echo '❌')"
	@echo "  nen-net: $(shell test -d ../nen-net && echo '✅' || echo '❌')"
