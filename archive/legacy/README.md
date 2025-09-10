# NenDB Legacy Tests

This directory contains legacy test files that are maintained for compatibility and reference.

## Legacy Test Files

### Resource Monitor Tests
- **test_resource_monitor.zig**: Legacy resource monitoring tests
- **Purpose**: Testing the resource monitoring functionality
- **Status**: Maintained for compatibility

### Cypher Parser Tests
- **test_cypher_parser.zig**: Legacy Cypher query parser tests
- **test_cypher_parser_new.zig**: Newer Cypher parser tests
- **Purpose**: Testing the query language parser
- **Status**: Being replaced by new parser implementation

## Migration Status

These tests are being gradually replaced by the new TDD workflow:

1. **Unit Tests** (`tests/unit/`) - ✅ **Active**
2. **Integration Tests** (`tests/integration/`) - 🔧 **In Progress**
3. **Performance Tests** (`tests/performance/`) - ✅ **Active**
4. **Stress Tests** (`tests/stress/`) - 🔧 **In Progress**

## Running Legacy Tests

```bash
# Run legacy tests (if still supported)
zig test tests/legacy/*.zig

# Run specific legacy test
zig test tests/legacy/test_resource_monitor.zig
```

## Deprecation Timeline

- **Phase 1**: Identify functionality covered by legacy tests
- **Phase 2**: Rewrite tests using new TDD workflow
- **Phase 3**: Migrate test logic to appropriate test categories
- **Phase 4**: Remove legacy tests (after validation)

## Contributing

When working with legacy tests:

1. **Don't add new tests here** - Use the new TDD workflow
2. **Document any bugs found** - Create issues for tracking
3. **Identify missing coverage** - Plan migration to new test categories
4. **Maintain compatibility** - Don't break existing functionality

## Test Categories

Legacy tests should be migrated to:

- **Unit Tests**: Individual function testing
- **Integration Tests**: Component interaction testing
- **Performance Tests**: Performance validation
- **Stress Tests**: Edge case and long-running testing
