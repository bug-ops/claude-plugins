---
name: fast-yaml
description: "Validate, format, and convert YAML/JSON files using the fast-yaml (fy) tool. Supports bidirectional YAML/JSON conversion and the YAML 1.2.2 spec with parallel processing for batch operations."
when_to_use: "'validate yaml', 'format yaml', 'lint yaml', 'check yaml syntax', 'convert yaml to json', 'convert json to yaml', 'yaml formatter', 'fix yaml formatting', 'json to yaml'."
effort: low
allowed-tools: Bash(fy *), Bash(pip *), Bash(npm *), Bash(cargo *)
---

# fast-yaml (fy) Tool

Professional YAML validation, formatting, and conversion tool with YAML 1.2.2 spec compliance and parallel processing capabilities.

> [!IMPORTANT]
> fast-yaml follows YAML 1.2.2 specification, which differs from PyYAML (1.1). Notable differences: `yes/no/on/off` are strings (not booleans), octal numbers use `0o` prefix.

## Quick Reference

| Operation | Command | Description |
|-----------|---------|-------------|
| Validate | `fy parse config.yaml` | Check YAML syntax |
| Format | `fy format -i config.yaml` | Format file in-place |
| Lint | `fy lint config.yaml` | Validate with diagnostics |
| YAML → JSON | `fy convert json config.yaml` | Convert YAML to JSON |
| JSON → YAML | `fy convert yaml config.json` | Convert JSON to YAML |
| Format many | `for f in $(git ls-files '*.yaml' '*.yml'); do fy format -i "$f"; done` | One file per call (Comment Safety) |

## Comment Safety (MANDATORY)

`fy` strips every YAML comment when it formats. On a single file, `fy format -i <file>` refuses with exit code 1 ("comments will be stripped") unless `--strip-comments` is passed. Batch mode — a directory, a glob, or several files — strips comments **silently and exits 0** (verified on fy 0.6.1), including the `# vX.Y.Z` comments of SHA-pinned GitHub Actions.

- Format one file per call; never pass a directory, glob, or several files to `fy format -i`, in scripts, hooks, or CI.
- Never pass `--strip-comments` to a file that has comments.
- A refusal means the file has comments: leave its formatting alone, or edit it by hand and check it with `fy lint`.

## Installation

### CLI Tool

```bash
# Rust (recommended for CLI)
cargo install fast-yaml-cli

# Verify installation
fy --version
```

### Python API

```bash
# Python bindings
pip install fastyaml-rs

# Verify installation
python -c "import fast_yaml; print(fast_yaml.__version__)"
```

### Node.js API

```bash
# Node.js bindings
npm install fastyaml-rs

# Verify installation
node -e "const fy = require('fastyaml-rs'); console.log('OK')"
```

> [!NOTE]
> Requires Rust 1.88+, Python 3.10+, or Node.js 20+ depending on the installation method.

## Common Workflows

### Single File Validation

```bash
# Validate syntax only
fy parse config.yaml

# Validate with detailed diagnostics
fy lint config.yaml

# Format and save
fy format -i config.yaml
```

### Batch Processing

```bash
# Format one file per call: batch mode strips comments silently (Comment Safety)
for f in $(git ls-files '*.yaml' '*.yml'); do fy format -i "$f"; done

# Lint a whole tree (read-only, safe in batch)
fy lint src/

# Lint with exclusions
fy lint --exclude "tests/**" .
```

> [!TIP]
> Use parallel processing (`-j` flag) for large codebases. Batch mode provides 6-15x speedup on multi-file operations.

### Format Conversion

#### YAML → JSON

```bash
# Convert to JSON (pretty-printed)
fy convert json config.yaml

# Compact JSON (no whitespace)
fy convert json --pretty false config.yaml

# Save to file
fy convert json config.yaml > config.json
```

#### JSON → YAML

```bash
# Convert to YAML
fy convert yaml config.json

# Convert and save
fy convert yaml config.json > config.yaml

# Write to a new file (-i would leave YAML inside a .json file)
fy convert yaml -o config.yaml config.json
```

> [!TIP]
> Bidirectional conversion is seamless. Use `fy convert yaml` for JSON → YAML and `fy convert json` for YAML → JSON.

## Python Integration

For programmatic YAML processing in Python:

```python
import fast_yaml

# Load YAML
data = fast_yaml.safe_load(yaml_string)

# Dump YAML with formatting
yaml_str = fast_yaml.safe_dump(data, indent=2, width=80)

# Lint with diagnostics
from fast_yaml.lint import lint
diagnostics = lint(yaml_string)
for diag in diagnostics:
    print(f"{diag.severity}: {diag.message} at line {diag.span.start.line}")
```

See [references/python-api.md](references/python-api.md) for complete Python API reference.

## Node.js Integration

For TypeScript/JavaScript projects:

```typescript
import { safeLoad, safeDump } from 'fastyaml-rs';

const data = safeLoad(`name: fast-yaml`);
const yamlStr = safeDump(data);
```

See [references/nodejs-api.md](references/nodejs-api.md) for complete Node.js API reference.

## YAML 1.2.2 Compliance

> [!WARNING]
> fast-yaml uses YAML 1.2.2 spec, which differs from PyYAML (1.1). Review [references/yaml-spec.md](references/yaml-spec.md) for migration guide.

Key differences from PyYAML (1.1):

| Value | PyYAML (1.1) | fast-yaml (1.2.2) |
|-------|--------------|-------------------|
| `yes/no` | Boolean | String |
| `on/off` | Boolean | String |
| `014` | 12 (octal) | 14 (decimal) |
| `0o14` | Error | 12 (octal) |

## Performance Characteristics

- **Small/medium files**: Matches PyYAML C (1.3-1.4x faster than js-yaml)
- **Batch mode**: 6-15x faster than sequential processors
- **Parallel documents**: 3-6x speedup on 4-8 core systems

> [!CAUTION]
> Process startup overhead (~15ms Python, ~20-25ms Node.js) affects single-file benchmarks. Use persistent servers or batch mode for best performance.

## When to Use This Skill

Use fast-yaml when you need to:

- **Validate YAML files** before deployment or CI/CD
- **Format YAML consistently** across a codebase
- **Convert YAML to JSON** for tooling compatibility
- **Lint YAML files** for syntax errors and best practices
- **Batch process** multiple YAML files with parallel execution
- **Ensure YAML 1.2.2 compliance** for standards conformance

## Additional Resources

- **CLI Reference**: [references/cli-commands.md](references/cli-commands.md) - Complete CLI command documentation
- **Python API**: [references/python-api.md](references/python-api.md) - Python integration examples
- **Node.js API**: [references/nodejs-api.md](references/nodejs-api.md) - TypeScript/JavaScript usage
- **YAML 1.2.2 Spec**: [references/yaml-spec.md](references/yaml-spec.md) - Specification differences and migration guide

## Examples

### Format All Kubernetes Manifests

```bash
# Format each manifest separately (batch mode would strip comments)
for f in k8s/*.yaml; do fy format -i "$f"; done

# Verify no syntax errors
fy lint k8s/
```

### CI/CD Validation

```bash
# Validate all YAML in repository
fy lint --exclude "node_modules/**" --exclude ".git/**" .

# fy has no format-check mode; CI validates with fy lint only
```

### Python Data Validation

```python
import fast_yaml
from fast_yaml.lint import lint

# Load and validate config
config_yaml = open("config.yaml").read()
diagnostics = lint(config_yaml)

if diagnostics:
    for diag in diagnostics:
        print(f"Error at line {diag.span.start.line}: {diag.message}")
    exit(1)

config = fast_yaml.safe_load(config_yaml)
```

## Troubleshooting

### Boolean Values Not Parsing as Expected

fast-yaml follows YAML 1.2.2, where `yes/no/on/off` are strings. Use explicit `true/false`:

```yaml
# Old (YAML 1.1 - PyYAML)
enabled: yes

# New (YAML 1.2.2 - fast-yaml)
enabled: true
```

See [references/yaml-spec.md](references/yaml-spec.md) for complete migration guide.

### Batch Formatting Removed Comments

Batch mode (`fy format -i <dir|glob|several files>`) strips every comment and still exits 0. Restore the files from git (`git checkout -- <paths>`) and format one file per call (Comment Safety). Batch mode is safe only for read-only commands such as `fy lint`.
