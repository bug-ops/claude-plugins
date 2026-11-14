# Use official Rust image as base
FROM rust:1-bookworm

# Install additional system dependencies
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends \
    # Development tools
    build-essential \
    pkg-config \
    libssl-dev \
    # Version control
    git \
    git-lfs \
    # Utilities
    curl \
    wget \
    ca-certificates \
    gnupg \
    lsb-release \
    # For debugging
    gdb \
    lldb \
    # Network tools
    netcat-traditional \
    iproute2 \
    # Text processing
    jq \
    # Archive extraction
    unzip \
    # Shell utilities
    zsh \
    fish \
    && rm -rf /var/lib/apt/lists/*

# Luau/Lua language servers and rokit: pinned release archives, sha256-verified
ARG ROKIT_VERSION=1.2.0
ARG LUAU_LSP_VERSION=1.70.1
ARG LUA_LS_VERSION=3.19.2
RUN set -eux; \
    case "$(uname -m)" in \
      x86_64) \
        rokit_asset=linux-x86_64; rokit_sha=951a7f3ec3d2a5e021fd1867d32f69f010ee4c2927f644b759578afc59c65fc0; \
        luau_asset=linux-x86_64; luau_sha=1a2ea1ae4f98f8946cefd970a4b54853e11ab4775e6932faa7f60cf920346567; \
        lual_asset=linux-x64; lual_sha=93ad326b10f6c00911dd8c450fa098332dbd8f9f45d1052f5636a2d54479b947 ;; \
      aarch64) \
        rokit_asset=linux-aarch64; rokit_sha=b9ba200dd70620d9dbc11bbb0b368a62c6891328e6bc5fab4b7f68200089553a; \
        luau_asset=linux-arm64; luau_sha=6062345b95124ca937b8c324b74bc3fddb1d6919ba133c58f8b17945ce1acbc2; \
        lual_asset=linux-arm64; lual_sha=17b8e401a874440adeb649e5024c364f2bb9d15156c74a40e56d1ae9a1b2e4f2 ;; \
      *) echo "unsupported architecture: $(uname -m)" >&2; exit 1 ;; \
    esac; \
    tmp="$(mktemp -d)"; \
    curl -fsSL -o "$tmp/rokit.zip" "https://github.com/rojo-rbx/rokit/releases/download/v${ROKIT_VERSION}/rokit-${ROKIT_VERSION}-${rokit_asset}.zip"; \
    curl -fsSL -o "$tmp/luau-lsp.zip" "https://github.com/JohnnyMorganz/luau-lsp/releases/download/${LUAU_LSP_VERSION}/luau-lsp-${luau_asset}.zip"; \
    curl -fsSL -o "$tmp/lua-ls.tar.gz" "https://github.com/LuaLS/lua-language-server/releases/download/${LUA_LS_VERSION}/lua-language-server-${LUA_LS_VERSION}-${lual_asset}.tar.gz"; \
    printf '%s  %s\n' "$rokit_sha" "$tmp/rokit.zip" "$luau_sha" "$tmp/luau-lsp.zip" "$lual_sha" "$tmp/lua-ls.tar.gz" | sha256sum -c -; \
    unzip -o "$tmp/rokit.zip" rokit -d /usr/local/bin; \
    unzip -o "$tmp/luau-lsp.zip" luau-lsp -d /usr/local/bin; \
    chmod 0755 /usr/local/bin/rokit /usr/local/bin/luau-lsp; \
    mkdir -p /usr/local/lib/lua-language-server; \
    tar -xzf "$tmp/lua-ls.tar.gz" -C /usr/local/lib/lua-language-server; \
    printf '#!/bin/sh\nexec /usr/local/lib/lua-language-server/bin/lua-language-server "$@"\n' > /usr/local/bin/lua-language-server; \
    chmod 0755 /usr/local/bin/lua-language-server; \
    rm -rf "$tmp"

# Create a non-root user
ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=$USER_UID

RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME \
    && apt-get update \
    && apt-get install -y sudo \
    && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME \
    && rm -rf /var/lib/apt/lists/*

# Install Rust tools for the vscode user
USER $USERNAME

# Set up Rust environment
ENV CARGO_HOME=/usr/local/cargo
ENV RUSTUP_HOME=/usr/local/rustup
ENV PATH=$CARGO_HOME/bin:$PATH

# Install common Rust development tools
RUN rustup component add \
    rustfmt \
    clippy \
    rust-src \
    rust-analyzer

# Nightly rustfmt for `cargo +nightly fmt --check`
RUN rustup toolchain install nightly --profile minimal --component rustfmt

# Install cargo tools
RUN cargo install --locked \
    # Testing
    cargo-nextest \
    cargo-tarpaulin \
    # Benchmarking
    cargo-criterion \
    # Security
    cargo-audit \
    cargo-deny \
    # Performance
    flamegraph \
    cargo-bloat \
    # Build optimization
    sccache \
    # Development
    cargo-watch \
    cargo-edit \
    cargo-outdated \
    # Documentation
    mdbook \
    # Plugin check suite
    cargo-machete \
    cargo-semver-checks \
    cargo-hack \
    cargo-expand \
    fast-yaml-cli \
    # Luau stack profile
    stylua \
    selene

# Configure sccache
ENV RUSTC_WRAPPER=sccache
ENV SCCACHE_DIR=/home/$USERNAME/.cache/sccache

# Set up shell (optional but nice for development)
RUN echo 'export PS1="\[\033[01;32m\]\u@rust-plugin\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ "' >> /home/$USERNAME/.bashrc

# Default command
CMD ["/bin/bash"]
