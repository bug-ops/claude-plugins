#!/bin/bash
set -e

echo "========================================="
echo "Running post-create setup..."
echo "========================================="

# Update Rust to latest stable
echo "Updating Rust toolchain..."
rustup update stable
rustup default stable

# Verify Rust installation
echo ""
echo "Rust toolchain information:"
rustc --version
cargo --version
rustfmt --version
clippy-driver --version

# Show installed cargo tools
echo ""
echo "Installed cargo tools:"
cargo install --list

# Set up git safe directory
echo ""
echo "Configuring git..."
git config --global --add safe.directory /workspace

# Initialize sccache directory
echo ""
echo "Setting up sccache..."
mkdir -p ~/.cache/sccache

# Install Claude Code CLI
echo ""
echo "Installing Claude Code CLI..."
npm install -g @anthropic-ai/claude-code

# Verify Claude Code installation
echo ""
echo "Claude Code version:"
claude --version

# Create Claude Code config directory
echo ""
echo "Setting up Claude Code..."
mkdir -p ~/.claude

# Install the plugin
echo ""
echo "Installing Rust Agents Plugin..."
if [ -d "/workspace/.claude-plugin" ]; then
    # Install plugin from the workspace
    claude plugin install /workspace
    echo "Plugin installed successfully!"

    # List installed plugins
    echo ""
    echo "Installed plugins:"
    claude plugin list

    # Show available agents
    echo ""
    echo "Available agents:"
    # Note: This command might need to be run in an interactive session
    # claude /agents
else
    echo "Warning: Plugin directory not found at /workspace/.claude-plugin"
    echo "You can install it manually with: claude plugin install /workspace"
fi

# Display environment info
echo ""
echo "========================================="
echo "Development environment ready!"
echo "========================================="
echo "Workspace: /workspace"
echo "User: $(whoami)"
echo "Rust version: $(rustc --version)"
echo "Cargo version: $(cargo --version)"
echo ""
echo "Available tools:"
echo "  - cargo-nextest (testing)"
echo "  - cargo-tarpaulin (coverage)"
echo "  - cargo-criterion (benchmarking)"
echo "  - cargo-audit (security)"
echo "  - cargo-deny (dependency checking)"
echo "  - cargo-flamegraph (profiling)"
echo "  - cargo-bloat (binary size analysis)"
echo "  - sccache (build caching)"
echo "  - cargo-watch (auto-rebuild)"
echo "  - cargo-edit (dependency management)"
echo "  - cargo-outdated (dependency updates)"
echo "  - mdbook (documentation)"
echo ""
echo "Claude Code:"
echo "  - Version: $(claude --version 2>/dev/null || echo 'Not available')"
echo "  - Config directory: ~/.claude"
echo "  - Plugin installed: rust-agents"
echo ""
echo "Rust Agents Plugin:"
echo "  - Location: /workspace"
echo "  - Agents directory: ./agents/"
echo "  - Manifest: ./.claude-plugin/plugin.json"
echo "  - Available agents: 7 (rust-architect, rust-developer, rust-testing-engineer,"
echo "                         rust-performance-engineer, rust-security-maintenance,"
echo "                         rust-code-reviewer, rust-cicd-devops)"
echo ""
echo "Quick start:"
echo "  1. Start Claude Code: claude"
echo "  2. View agents: /agents"
echo "  3. View plugins: /plugin list"
echo "========================================="
