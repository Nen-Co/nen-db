FROM ubuntu:22.04

# Install system dependencies
RUN apt-get update && apt-get install -y \
    curl \
    build-essential \
    xz-utils \
    && rm -rf /var/lib/apt/lists/*

# Install Zig (fixed method)
RUN curl -L https://ziglang.org/download/0.14.1/zig-linux-x86_64-0.14.1.tar.xz -o zig.tar.xz \
    && tar -xf zig.tar.xz \
    && mv zig-linux-x86_64-0.14.1 /usr/local/zig \
    && rm zig.tar.xz

# Add Zig to PATH
ENV PATH="/usr/local/zig:${PATH}"

# Set working directory
WORKDIR /app

# Copy source code
COPY . .

# Build NenDB
RUN zig build -Doptimize=ReleaseSafe

# Create data directory
RUN mkdir -p /data

# Expose port for TCP server
EXPOSE 5454

# Set environment variables
ENV NENDB_DATA_DIR=/data
ENV NENDB_SYNC_EVERY=100
ENV NENDB_SEGMENT_SIZE=1048576

# Default command
CMD ["./zig-out/bin/nen", "serve"]
