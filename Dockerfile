FROM ubuntu:24.04 AS builder

RUN apt-get update && apt-get install -y \
    xz-utils ca-certificates pkg-config libglib2.0-dev make curl git gcc \
    && rm -rf /var/lib/apt/lists/*

# Install Zig 0.15.2
RUN ARCH=$(uname -m) && \
    curl -L -o /tmp/zig.tar.xz "https://ziglang.org/download/0.15.2/zig-${ARCH}-linux-0.15.2.tar.xz" && \
    tar -xJf /tmp/zig.tar.xz -C /opt && \
    ln -s /opt/zig-${ARCH}-linux-0.15.2/zig /usr/local/bin/zig && \
    rm /tmp/zig.tar.xz

# Install Rust
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
ENV PATH="/root/.cargo/bin:${PATH}"

# Download prebuilt V8 (stealth patches are Zig-side, not in V8)
RUN ARCH=$(uname -m) && \
    if [ "$ARCH" = "aarch64" ]; then V8_ARCH="aarch64"; else V8_ARCH="x86_64"; fi && \
    mkdir -p /v8 && \
    curl -L -o /v8/libc_v8.a \
      "https://github.com/lightpanda-io/zig-v8-fork/releases/download/v0.3.8/libc_v8_14.0.365.4_linux_${V8_ARCH}.a"

WORKDIR /stealthpanda
COPY . .

# Build with prebuilt V8
RUN zig build -Doptimize=ReleaseFast -Dprebuilt_v8_path=/v8/libc_v8.a

FROM ubuntu:24.04
RUN apt-get update && apt-get install -y libglib2.0-0 ca-certificates && rm -rf /var/lib/apt/lists/*
COPY --from=builder /stealthpanda/zig-out/bin/lightpanda /usr/local/bin/lightpanda

EXPOSE 9222
ENTRYPOINT ["lightpanda", "serve", "--host", "0.0.0.0", "--port", "9222"]
