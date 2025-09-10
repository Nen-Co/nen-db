# NenDB Docker Images

NenDB provides official Docker images via GitHub Container Registry (GHCR) for easy deployment and testing.

## 🏷️ Image Tags

- **Latest**: `ghcr.io/nen-co/nendb:latest`
- **Versioned**: `ghcr.io/nen-co/nendb:v0.1.0-beta`
- **Simple variant**: `ghcr.io/nen-co/nendb:simple-latest`

## 🚀 Quick Start

### Pull and Run (HTTP Server)
```bash
# Pull the latest image
docker pull ghcr.io/nen-co/nendb:latest

# Run with HTTP server on port 8080
docker run --rm -p 8080:8080 --name nendb \
  -v $(pwd)/data:/data \
  ghcr.io/nen-co/nendb:latest
```

### Run with Custom Data Directory
```bash
docker run --rm -p 8080:8080 --name nendb \
  -v /path/to/your/data:/data \
  ghcr.io/nen-co/nendb:latest
```

### Run in Background
```bash
docker run -d --name nendb \
  -p 8080:8080 \
  -v $(pwd)/data:/data \
  ghcr.io/nen-co/nendb:latest
```

## 🔌 Ports

- **8080**: HTTP API server (default)
- **5454**: TCP server (if needed)

## 📁 Data Persistence

The `/data` volume mount persists your graph database data between container restarts.

## 🧪 Test the Container

```bash
# Health check
curl http://localhost:8080/health

# Graph statistics
curl http://localhost:8080/graph/stats

# List available endpoints
curl http://localhost:8080/
```

## 🐳 Docker Compose

```yaml
version: '3.8'
services:
  nendb:
    image: ghcr.io/nen-co/nendb:latest
    ports:
      - "8080:8080"
    volumes:
      - ./data:/data
    environment:
      - NENDB_DATA_DIR=/data
    restart: unless-stopped
```

## 🔧 Build Locally

If you prefer to build the image locally:

```bash
# Clone the repository
git clone https://github.com/Nen-Co/nen-db.git
cd nen-db

# Build the image
docker build -t nendb:local .

# Run locally built image
docker run --rm -p 8080:8080 nendb:local
```

## 📋 System Requirements

- **Memory**: 512MB minimum
- **Storage**: 1GB minimum for data directory
- **Architecture**: Linux/amd64, Linux/arm64

## 🆘 Troubleshooting

### Container won't start
```bash
# Check container logs
docker logs nendb

# Check if port is already in use
lsof -i :8080
```

### Permission issues with data directory
```bash
# Ensure data directory has correct permissions
mkdir -p ./data
chmod 755 ./data
```

### Out of memory
```bash
# Increase Docker memory limit
docker run --rm -p 8080:8080 --memory=1g \
  -v $(pwd)/data:/data \
  ghcr.io/nen-co/nendb:latest
```

## 🔗 Related Links

- [NenDB Documentation](https://nen-co.github.io/docs/nendb/)
- [API Reference](https://nen-co.github.io/docs/nendb/api/)
- [GitHub Repository](https://github.com/Nen-Co/nen-db)
- [GitHub Container Registry](https://ghcr.io/nen-co/nendb)
