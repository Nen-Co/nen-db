Release checklist

1. Verify tests pass locally:
   - zig test tests/*.zig
   - zig test src/*.zig
2. Ensure build produces binaries:
   - zig build -Drelease-safe
3. Run smoke demo or Docker image
4. Tag the release and push the tag:
   - git tag -a v0.0.1 -m "v0.0.1"
   - git push origin v0.0.1
5. Ensure CI passes on main branch
6. After GitHub Release artifacts appear, download and verify binaries
7. Publish release notes, update website/docs

Artifacts produced by CI/release workflows will include:
- tar.gz of the built binary
- checksums (future improvement)
