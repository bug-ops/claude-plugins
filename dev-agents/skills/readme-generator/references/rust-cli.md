# Rust CLI Tool README Template

> [!IMPORTANT]
> CLI tools need comprehensive installation options. Users without Rust toolchain must have pre-built binaries.

## Structure

```markdown
# tool-name

[![Crates.io](https://img.shields.io/crates/v/{crate})](https://crates.io/crates/{crate})
[![CI](https://img.shields.io/github/actions/workflow/status/{owner}/{repo}/ci.yml?branch=main)](https://github.com/{owner}/{repo}/actions)
[![License](https://img.shields.io/crates/l/{crate})](LICENSE)

One-line description of what the tool does.

![Demo GIF](assets/demo.gif)

## Installation

### From crates.io

\`\`\`bash
cargo install {crate}
\`\`\`

### From source

\`\`\`bash
git clone https://github.com/{owner}/{repo}
cd {repo}
cargo install --path .
\`\`\`

> [!TIP]
> Use `cargo binstall {crate}` for faster installation without compilation.

### Package managers

<details>
<summary>Homebrew (macOS/Linux)</summary>

\`\`\`bash
brew install {crate}
\`\`\`
</details>

<details>
<summary>Arch Linux</summary>

\`\`\`bash
pacman -S {crate}
\`\`\`
</details>

<details>
<summary>Nix</summary>

\`\`\`bash
nix-env -iA nixpkgs.{crate}
\`\`\`
</details>

### Pre-built binaries

Download from [GitHub Releases](https://github.com/{owner}/{repo}/releases/latest):

| Platform | Architecture | Download |
|----------|--------------|----------|
| Linux | x86_64 | [{crate}-x86_64-unknown-linux-gnu.tar.gz](...) |
| Linux | aarch64 | [{crate}-aarch64-unknown-linux-gnu.tar.gz](...) |
| macOS | x86_64 | [{crate}-x86_64-apple-darwin.tar.gz](...) |
| macOS | aarch64 | [{crate}-aarch64-apple-darwin.tar.gz](...) |
| Windows | x86_64 | [{crate}-x86_64-pc-windows-msvc.zip](...) |

## Usage

\`\`\`bash
{crate} [OPTIONS] <COMMAND>
\`\`\`

### Basic examples

\`\`\`bash
# Example 1
{crate} command arg

# Example 2
{crate} --flag value input.txt
\`\`\`

### Commands

| Command | Description |
|---------|-------------|
| `command1` | Does X |
| `command2` | Does Y |

### Options

| Option | Short | Description | Default |
|--------|-------|-------------|---------|
| `--verbose` | `-v` | Increase verbosity | false |
| `--config` | `-c` | Config file path | `~/.config/{crate}/config.toml` |

## Configuration

Configuration file location: `~/.config/{crate}/config.toml`

\`\`\`toml
# Example configuration
option = "value"
\`\`\`

> [!NOTE]
> Environment variables override config file values. Use `{CRATE}_OPTION=value`.

## Shell completions

> [!TIP]
> Enable shell completions for better UX. Supports bash, zsh, fish, and PowerShell.

Generate shell completions:

\`\`\`bash
# Bash
{crate} completions bash > ~/.local/share/bash-completion/completions/{crate}

# Zsh
{crate} completions zsh > ~/.zsh/completions/_{crate}

# Fish
{crate} completions fish > ~/.config/fish/completions/{crate}.fish
\`\`\`

## License

Licensed under {license} - see [LICENSE](LICENSE).
```

## CLI-Specific Requirements

### Visual Demo

> [!TIP]
> A 10-second GIF showing the tool in action is worth 1000 words. Use `asciinema` + `agg` for terminal recordings.

CLI tools benefit greatly from visual demos. Priority:

1. **GIF demo** - Best for showing workflow (use `asciinema` + `agg`)
2. **Screenshot** - Good for showing output
3. **ASCII art logo** - Nice touch for branding

Recording a GIF:

```bash
# Record terminal
asciinema rec demo.cast

# Convert to GIF
agg demo.cast demo.gif --font-size 14 --cols 80 --rows 24
```

### Installation Section

CLI tools need comprehensive installation options. Order by accessibility:

1. **Package managers** (Homebrew, apt, pacman, etc.)
2. **cargo install** (for Rust developers)
3. **Pre-built binaries** (for users without Rust)
4. **From source** (for contributors)

Use `<details>` for less common package managers to avoid clutter.

### Binary Size

If binary is notably small, mention it:

```markdown
Minimal binary size: ~2MB (statically linked)
```

### Platform Support

Document supported platforms explicitly:

```markdown
## Supported Platforms

- Linux (x86_64, aarch64)
- macOS (x86_64, aarch64/Apple Silicon)
- Windows (x86_64)
```

### Usage Examples

Show real-world usage scenarios:

```markdown
## Examples

### Process all files in directory

\`\`\`bash
{crate} process ./input/*.txt -o ./output/
\`\`\`

### Use with pipes

\`\`\`bash
cat input.txt | {crate} transform | grep pattern
\`\`\`

### Watch mode

\`\`\`bash
{crate} watch ./src --exec "cargo build"
\`\`\`
```

### Comparison with Alternatives

If tool is faster/better than alternatives, show benchmarks:

```markdown
## Performance

Comparison with similar tools:

| Tool | Time | Memory |
|------|------|--------|
| {crate} | 0.5s | 10MB |
| alternative1 | 2.3s | 50MB |
| alternative2 | 5.1s | 120MB |

Benchmarked on [dataset] with [hardware].
```

### Configuration File

Document config file format completely:

```markdown
## Configuration

Default location: `~/.config/{crate}/config.toml`

\`\`\`toml
# All available options with defaults

[section]
option1 = "default"  # Description
option2 = true       # Description
\`\`\`

Environment variables override config file:

| Variable | Config equivalent |
|----------|-------------------|
| `{CRATE}_OPTION1` | `section.option1` |
```

### Shell Completions

Always document shell completion generation:

```bash
# Generate completions
{crate} completions bash
{crate} completions zsh
{crate} completions fish
{crate} completions powershell
```

### Man Pages

If man pages are generated:

```markdown
## Documentation

Man pages are installed with the binary:

\`\`\`bash
man {crate}
man {crate}-subcommand
\`\`\`
```

## Badge Priority for CLI Tools

1. Crates.io version (required)
2. CI status (required - shows tool works)
3. License (required)
4. Downloads (good social proof)
5. MSRV (optional for CLI tools)

## GitHub Releases Integration

Link to releases for pre-built binaries:

```markdown
### Pre-built binaries

Download the latest release for your platform from
[GitHub Releases](https://github.com/{owner}/{repo}/releases/latest).

After downloading:

\`\`\`bash
# Linux/macOS
tar -xzf {crate}-*.tar.gz
chmod +x {crate}
sudo mv {crate} /usr/local/bin/

# Windows
# Extract zip and add to PATH
\`\`\`
```
