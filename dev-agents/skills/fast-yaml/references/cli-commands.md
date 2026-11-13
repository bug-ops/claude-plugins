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
| `--no-color` | Disable colored output |
| `-i, --in-place` | Edit the file in place (requires a file argument) |
| `-o, --output <FILE>` | Write to a file instead of stdout |
| `-f, --format <FORMAT>` | Output format: `yaml` (default), `json`, `compact` |

## Commands

### `parse` - Validate YAML Syntax

Validates YAML files for syntax errors without performing any transformations.

```bash
fy parse [OPTIONS] [FILE]
```

Takes one file, or stdin when `FILE` is omitted. Directories, `-r`, and `--exclude` are not supported; use `fy lint` for several files.

**Options:**

| Option | Description |
|--------|-------------|
| `--stats` | Show parse statistics |

**Examples:**

```bash
# Validate single file
fy parse config.yaml

# Validate from stdin
cat config.yaml | fy parse

# Show statistics
fy parse --stats config.yaml
```

**Exit Codes:**

- `0` - File is valid
- `1` - Syntax error, or file not found or unreadable
- `2` - Usage error (unknown or extra argument)

### `format` - Format YAML Files

**Comment safety:** `fy format` strips YAML comments. On one file it refuses (exit 1) unless `--strip-comments` is passed; with a directory, glob, or several files it strips them silently and exits 0 (fy 0.6.1). Format one file per call; the batch `format` examples in this file are only for files without comments. See the SKILL's Comment Safety section.

Formats YAML files according to standard conventions with configurable indentation and line width.

```bash
fy format [OPTIONS] [PATHS]...
```

**Options:**

| Option | Description | Default |
|--------|-------------|---------|
| `-i, --in-place` | Modify files in-place | false |
| `--indent <N>` | Indentation spaces | 2 |
| `--width <N>` | Maximum line width | 80 |
| `-j, --jobs <N>` | Parallel workers (batch mode) | CPU cores |
| `-n, --dry-run` | Show what would change without modifying files | false |
| `--include <PATTERN>` | Include only files matching glob (repeatable) | all YAML |
| `--exclude <PATTERN>` | Exclude files matching glob (repeatable) | none |
| `--no-recursive` | Do not recurse into subdirectories | false |
| `--strip-comments` | Allow formatting files that contain comments (they are stripped) | false |
| `--stdin-files` | Read file paths from stdin, one per line | false |

There is no check mode: `fy format --check` fails with a usage error (exit 2), and `fy format -n` exits 0 even when files would change.

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

# Preview changes without modifying files (exit 0 either way)
fy format -n src/
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
- `1` - Formatting error, file not found, or a single file with comments refused without `--strip-comments`
- `2` - Usage error (unknown argument)

### `lint` - Validate with Diagnostics

Performs comprehensive validation with detailed diagnostic messages, including:
- Syntax errors
- Duplicate keys
- Type inconsistencies
- Best practice violations

```bash
fy lint [OPTIONS] [PATHS]...
```

Paths may be files, directories (searched recursively), or glob patterns.

**Options:**

| Option | Description |
|--------|-------------|
| `--format <text\|json>` | Diagnostic output format (default `text`) |
| `--include <PATTERN>` | Include only files matching glob (repeatable) |
| `--exclude <PATTERN>` | Exclude files matching glob (repeatable) |
| `--no-recursive` | Do not recurse into subdirectories |
| `--config <FILE>` / `--no-config` | Use a config file / disable `.fast-yaml.yaml` auto-discovery |
| `--max-line-length <N>` | Maximum line length |
| `--indent-size <N>` | Indentation size |
| `--allow-duplicate-keys [true\|false]` | Suppress duplicate key errors |
| `-j, --jobs <N>` | Parallel workers |

**Examples:**

```bash
# Lint single file
fy lint config.yaml

# Lint with exclusions
fy lint --exclude "tests/**" --exclude "node_modules/**" .

# JSON output for CI/CD
fy lint --format json src/ > diagnostics.json

# Lint a directory (recursive by default)
fy lint project/
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

`--format json` prints an array of diagnostics. Each has `code`, `severity`, `message`, `span` (`start`/`end` with `line`, `column`, `offset`), `context`, and `suggestions`; with several files each entry also carries `file`.

```json
[
  {
    "code": "duplicate-key",
    "severity": "error",
    "message": "duplicate key 'a' (first defined at line 1)",
    "span": {
      "start": {"line": 2, "column": 1, "offset": 5},
      "end": {"line": 2, "column": 2, "offset": 6}
    }
  }
]
```

**Exit Codes** (fy 0.6.1):

- `0` - No errors (warnings alone still exit 0)
- `1` - Syntax error, or file not found or unreadable
- `2` - Lint errors such as a duplicate key, or a usage error

### `convert` - Convert Between YAML and JSON

Converts between YAML and JSON formats with bidirectional support.

```bash
fy convert [OPTIONS] <TO> [FILE]
```

**Arguments:**

| Argument | Description | Values |
|----------|-------------|--------|
| `<TO>` | Target format | `json`, `yaml` |
| `<FILE>` | Input file | File path, or omit to read stdin |

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

# Convert to a file
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

**In-place conversion:** `fy convert <TO> -i <file>` rewrites the content but keeps the file name, so `fy convert yaml -i c.json` leaves YAML in a file named `.json`. Use `-o` with the new extension instead.

**Exit Codes:**

- `0` - Success
- `1` - Invalid input, or file not found or unreadable
- `2` - Usage error (unknown argument)

## Glob Patterns

**Comment safety:** `fy format` strips YAML comments. On one file it refuses (exit 1) unless `--strip-comments` is passed; with a directory, glob, or several files it strips them silently and exits 0 (fy 0.6.1). Format one file per call; the batch `format` examples in this file are only for files without comments. See the SKILL's Comment Safety section.

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
fy lint --exclude "node_modules/**" --exclude "dist/**" "**/*.yaml"
```

## Exclusion Patterns

Use `--exclude` to skip files or directories:

```bash
# Single exclusion
fy lint --exclude "tests/**" .

# Multiple exclusions
fy lint \
  --exclude "node_modules/**" \
  --exclude ".git/**" \
  --exclude "dist/**" \
  .
```

## Environment Variables

| Variable | Description |
|----------|-------------|
| `NO_COLOR` | Disable colored output (same as `--no-color`) |

fy 0.6.1 reads no other environment variables; set worker count with `-j`.

## CI/CD Integration

### GitHub Actions

```yaml
name: Validate YAML

on: [push, pull_request]

jobs:
  yaml-lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@<40-char-sha> # vX.Y.Z
      - name: Install fast-yaml
        run: cargo install fast-yaml-cli
      - name: Lint YAML files
        run: fy lint --exclude "node_modules/**" .
```

### GitLab CI

```yaml
yaml-validation:
  image: rust:latest
  before_script:
    - cargo install fast-yaml-cli
  script:
    - fy lint --exclude "vendor/**" .
```

### Pre-commit Hook

```bash
#!/bin/bash
# .git/hooks/pre-commit

# Format YAML files
# One file per call: batch mode strips comments silently and exits 0
for f in $(git diff --cached --name-only --diff-filter=ACM | grep -E '\.(yaml|yml)$'); do
  fy format -i "$f" || exit 1   # refuses (exit 1) when the file has comments
done

# Re-add formatted files
git add $(git diff --cached --name-only --diff-filter=ACM | grep -E '\.(yaml|yml)$')

# Lint all staged YAML
fy lint $(git diff --cached --name-only --diff-filter=ACM | grep -E '\.(yaml|yml)$')
```

## Performance Tuning

**Comment safety:** `fy format` strips YAML comments. On one file it refuses (exit 1) unless `--strip-comments` is passed; with a directory, glob, or several files it strips them silently and exits 0 (fy 0.6.1). Format one file per call; the batch `format` examples in this file are only for files without comments. See the SKILL's Comment Safety section.

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

For very large files or batch operations, process files sequentially to reduce memory:

```bash
fy format -i -j 1 large-files/
```

## Troubleshooting

### "Permission denied" errors

```bash
# Check file permissions
ls -la config.yaml

# Fix ownership or mode so the current user can read and write the file
chmod u+rw config.yaml
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

# Profile with verbose output
fy -v format -i -j 8 project/
```
