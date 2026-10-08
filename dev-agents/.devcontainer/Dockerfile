# Use official Rust image as base
FROM rust:1.83-bookworm

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
    # Shell utilities
    zsh \
    fish \
    && rm -rf /var/lib/apt/lists/*

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
    cargo-flamegraph \
    cargo-bloat \
    # Build optimization
    sccache \
    # Development
    cargo-watch \
    cargo-edit \
    cargo-outdated \
    # Documentation
    mdbook

# Configure sccache
ENV RUSTC_WRAPPER=sccache
ENV SCCACHE_DIR=/home/$USERNAME/.cache/sccache

# Set up shell (optional but nice for development)
RUN echo 'export PS1="\[\033[01;32m\]\u@rust-plugin\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ "' >> /home/$USERNAME/.bashrc

# Set working directory
WORKDIR /workspace

# Default command
CMD ["/bin/bash"]
