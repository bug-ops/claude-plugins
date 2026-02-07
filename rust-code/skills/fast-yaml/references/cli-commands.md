# CLI Commands Reference

Complete reference for fast-yaml (fy) command-line interface.

## Global Options

```bash
fy [OPTIONS] <COMMAND>
```

| Option | Description |
|--------|-------------|
| `-h, --help` | Print help information |
| `-V, --version` | Print version information |
| `-v, --verbose` | Enable verbose output |
| `-q, --quiet` | Suppress all output except errors |

## Commands

### `parse` - Validate YAML Syntax

Validates YAML files for syntax errors without performing any transformations.

```bash
fy parse [OPTIONS] <FILE>...
```

**Options:**

| Option | Description |
|--------|-------------|
| `-r, --recursive` | Process directories recursively |
| `--exclude <PATTERN>` | Exclude files matching glob pattern |

**Examples:**

```bash
# Validate single file
fy parse config.yaml

# Validate multiple files
fy parse config.yaml deployment.yaml

# Validate all YAML in directory
fy parse -r src/

# Validate with exclusions
fy parse --exclude "tests/**" .
```

**Exit Codes:**

- `0` - All files are valid
- `1` - Syntax errors found
- `2` - File not found or permission denied

### `format` - Format YAML Files

Formats YAML files according to standard conventions with configurable indentation and line width.

```bash
fy format [OPTIONS] <FILE|DIR|PATTERN>...
```

**Options:**

| Option | Description | Default |
|--------|-------------|---------|
| `-i, --in-place` | Modify files in-place | false |
| `--indent <N>` | Indentation spaces | 2 |
| `--width <N>` | Maximum line width | 80 |
| `-j, --jobs <N>` | Parallel workers (batch mode) | CPU cores |
| `--check` | Exit with code 1 if formatting needed | false |
| `--exclude <PATTERN>` | Exclude files matching pattern | none |

**Examples:**

```bash
# Format to stdout
fy format config.yaml

# Format in-place
fy format -i config.yaml

# Format with custom indentation
fy format -i --indent 4 config.yaml

# Format entire directory
fy format -i src/

# Format with glob pattern
fy format -i "**/*.yaml"

# Parallel processing (8 workers)
fy format -i -j 8 project/

# Check formatting without changes
fy format --check src/
```

**Batch Mode:**

Batch mode automatically activates when:
- Input is a directory
- Input is a glob pattern (`*`, `**`)
- Multiple files are specified

**Performance Tips:**

```bash
# ❌ Slow: Sequential processing
for f in $(find . -name "*.yaml"); do
  fy format -i "$f"
done

# ✅ Fast: Batch mode with parallelization
fy format -i -j 8 .
```

**Exit Codes:**

- `0` - Success
- `1` - Formatting errors or `--check` failed
- `2` - File not found or permission denied

### `lint` - Validate with Diagnostics

Performs comprehensive validation with detailed diagnostic messages, including:
- Syntax errors
- Duplicate keys
- Type inconsistencies
- Best practice violations

```bash
fy lint [OPTIONS] <FILE>...
```

**Options:**

| Option | Description |
|--------|-------------|
| `-r, --recursive` | Process directories recursively |
| `--exclude <PATTERN>` | Exclude files matching pattern |
| `--json` | Output diagnostics in JSON format |
| `--no-color` | Disable colored output |

**Examples:**

```bash
# Lint single file
fy lint config.yaml

# Lint with exclusions
fy lint --exclude "tests/**" --exclude "node_modules/**" .

# JSON output for CI/CD
fy lint --json src/ > diagnostics.json

# Lint recursively
fy lint -r project/
```

**Diagnostic Format:**

```
error: duplicate key 'database' found
  --> config.yaml:12:1
   |
12 | database:
   | ^^^^^^^^ key already defined at line 5
```

**JSON Output Format:**

```json
{
  "file": "config.yaml",
  "diagnostics": [
    {
      "severity": "error",
      "message": "duplicate key 'database' found",
      "span": {
        "start": {"line": 12, "column": 1},
        "end": {"line": 12, "column": 9}
      }
    }
  ]
}
```

**Exit Codes:**

- `0` - No issues found
- `1` - Warnings or errors found
- `2` - File not found or permission denied

### `convert` - Convert Between YAML and JSON

Converts between YAML and JSON formats with bidirectional support.

```bash
fy convert <TO> [OPTIONS] <FILE>
```

**Arguments:**

| Argument | Description | Values |
|----------|-------------|--------|
| `<TO>` | Target format | `json`, `yaml` |
| `<FILE>` | Input file | File path or `-` for stdin |

**Options:**

| Option | Description | Default |
|--------|-------------|---------|
| `--pretty [true\|false]` | Pretty-print output | true |
| `-i, --in-place` | Edit file in-place | false |
| `-o, --output <FILE>` | Write to file instead of stdout | stdout |

#### YAML → JSON Conversion

**Examples:**

```bash
# Convert to JSON (pretty-printed)
fy convert json config.yaml

# Compact JSON (no whitespace)
fy convert json --pretty false config.yaml

# Convert and save
fy convert json config.yaml > config.json

# In-place conversion
fy convert json -i config.yaml

# Convert to file with output flag
fy convert json -o config.json config.yaml
```

**Multi-Document Handling:**

For YAML files with multiple documents (`---` separator), converts to JSON array:

```yaml
# input.yaml
---
name: doc1
---
name: doc2
```

```bash
fy convert json input.yaml
# Output: [{"name":"doc1"},{"name":"doc2"}]
```

#### JSON → YAML Conversion

**Examples:**

```bash
# Convert to YAML
fy convert yaml config.json

# Convert and save
fy convert yaml config.json > config.yaml

# In-place conversion
fy convert yaml -i config.json

# Convert to file with output flag
fy convert yaml -o config.yaml config.json

# From stdin
cat config.json | fy convert yaml
echo '{"name":"test","value":123}' | fy convert yaml
```

**Output:**

```yaml
name: test
value: 123
```

**JSON Array Handling:**

JSON arrays are converted to YAML multi-document format:

```json
[
  {"name": "doc1"},
  {"name": "doc2"}
]
```

```bash
fy convert yaml input.json
```

**Output:**

```yaml
---
name: doc1
---
name: doc2
```

**Exit Codes:**

- `0` - Success
- `1` - Conversion error (invalid input format)
- `2` - File not found or permission denied

## Glob Patterns

fast-yaml supports standard glob patterns:

| Pattern | Matches |
|---------|---------|
| `*.yaml` | All `.yaml` files in current directory |
| `**/*.yaml` | All `.yaml` files recursively |
| `src/**/*.yml` | All `.yml` files under `src/` |
| `*.{yaml,yml}` | Files with `.yaml` or `.yml` extension |

**Examples:**

```bash
# All YAML/YML files recursively
fy format -i "**/*.{yaml,yml}"

# All config files in any config/ directory
fy lint "**/config/*.yaml"

# Exclude patterns
fy format -i --exclude "node_modules/**" --exclude "dist/**" "**/*.yaml"
```

## Exclusion Patterns

Use `--exclude` to skip files or directories:

```bash
# Single exclusion
fy format -i --exclude "tests/**" .

# Multiple exclusions
fy lint \
  --exclude "node_modules/**" \
  --exclude ".git/**" \
  --exclude "dist/**" \
  .
```

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `FY_COLOR` | Enable/disable colored output (`always`, `auto`, `never`) | `auto` |
| `FY_JOBS` | Default number of parallel workers | CPU cores |
| `FY_MAX_INPUT_SIZE` | Maximum input file size (bytes) | 100MB |

**Examples:**

```bash
# Disable colors
FY_COLOR=never fy lint config.yaml

# Force 4 workers
FY_JOBS=4 fy format -i project/

# Increase max file size to 500MB
FY_MAX_INPUT_SIZE=524288000 fy parse large-file.yaml
```

## CI/CD Integration

### GitHub Actions

```yaml
name: Validate YAML

on: [push, pull_request]

jobs:
  yaml-lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Install fast-yaml
        run: cargo install fast-yaml-cli
      - name: Lint YAML files
        run: fy lint --exclude "node_modules/**" .
      - name: Check formatting
        run: fy format --check .
```

### GitLab CI

```yaml
yaml-validation:
  image: rust:latest
  before_script:
    - cargo install fast-yaml-cli
  script:
    - fy lint --exclude "vendor/**" .
    - fy format --check .
```

### Pre-commit Hook

```bash
#!/bin/bash
# .git/hooks/pre-commit

# Format YAML files
fy format -i $(git diff --cached --name-only --diff-filter=ACM | grep -E '\.(yaml|yml)$')

# Re-add formatted files
git add $(git diff --cached --name-only --diff-filter=ACM | grep -E '\.(yaml|yml)$')

# Lint all staged YAML
fy lint $(git diff --cached --name-only --diff-filter=ACM | grep -E '\.(yaml|yml)$')
```

## Performance Tuning

### Optimal Worker Count

```bash
# Auto-detect (default)
fy format -i project/

# Explicit worker count
fy format -i -j 8 project/

# Single-threaded (for debugging)
fy format -i -j 1 project/
```

**Guidelines:**

- **Small files (<100KB)**: Use `-j 4` or `-j 8`
- **Large files (>1MB)**: Use `-j 2` or `-j 4` to avoid memory pressure
- **Mixed sizes**: Use default (auto-detect)

### Memory Usage

For very large files or batch operations:

```bash
# Increase max input size (default: 100MB)
FY_MAX_INPUT_SIZE=524288000 fy format -i large-dataset.yaml

# Process files sequentially to reduce memory
fy format -i -j 1 large-files/
```

## Troubleshooting

### "Permission denied" errors

```bash
# Check file permissions
ls -la config.yaml

# Run with appropriate permissions
sudo fy format -i /etc/config.yaml
```

### "File too large" errors

```bash
# Increase max input size
FY_MAX_INPUT_SIZE=524288000 fy parse huge-file.yaml
```

### Batch mode not activating

Ensure you're using:
- Directory paths: `fy format -i src/`
- Glob patterns: `fy format -i "**/*.yaml"`
- Multiple files: `fy format -i file1.yaml file2.yaml`

### Slow performance

```bash
# Use parallel processing
fy format -i -j 8 project/

# Check worker count
echo $FY_JOBS

# Profile with verbose output
fy -v format -i -j 8 project/
```
