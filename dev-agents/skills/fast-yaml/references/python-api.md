# Python API Reference

Complete reference for using fast-yaml in Python applications.

## Installation

```bash
pip install fastyaml-rs
```

**Requirements:**

- Python 3.10 or later
- pip 21.0 or later (for wheel support)

**Verify installation:**

```bash
python -c "import fast_yaml; print(fast_yaml.__version__)"
```

## Core API

### Loading YAML

#### `safe_load(stream)` - Load Single Document

Parses a YAML string or file stream into a Python object.

```python
import fast_yaml

# From string
yaml_str = """
name: example
version: 1.0
enabled: true
"""
data = fast_yaml.safe_load(yaml_str)
print(data)  # {'name': 'example', 'version': '1.0', 'enabled': True}

# From file
with open('config.yaml') as f:
    data = fast_yaml.safe_load(f)
```

**Parameters:**

- `stream` (str | io.TextIOBase): YAML string or file object

**Returns:**

- Python object (dict, list, str, int, float, bool, or None)

**Raises:**

- `YAMLError`: On syntax errors or invalid YAML

#### `safe_load_all(stream)` - Load Multiple Documents

Parses multiple YAML documents separated by `---`.

```python
import fast_yaml

yaml_str = """
---
name: doc1
value: 100
---
name: doc2
value: 200
"""

for doc in fast_yaml.safe_load_all(yaml_str):
    print(doc)
# Output:
# {'name': 'doc1', 'value': 100}
# {'name': 'doc2', 'value': 200}
```

**Parameters:**

- `stream` (str | io.TextIOBase): YAML string or file object

**Returns:**

- Iterator of Python objects

**Raises:**

- `YAMLError`: On syntax errors

### Dumping YAML

#### `safe_dump(data, **kwargs)` - Serialize Single Document

Converts a Python object to YAML string.

```python
import fast_yaml

data = {
    'name': 'example',
    'version': '1.0',
    'features': ['fast', 'safe', 'spec-compliant']
}

yaml_str = fast_yaml.safe_dump(data)
print(yaml_str)
```

**Output:**

```yaml
name: example
version: '1.0'
features:
  - fast
  - safe
  - spec-compliant
```

**Parameters:**

- `data`: Python object to serialize
- `indent` (int): Indentation spaces (default: 2)
- `width` (int): Maximum line width (default: 80)
- `explicit_start` (bool): Add `---` document marker (default: False)
- `explicit_end` (bool): Add `...` document marker (default: False)
- `sort_keys` (bool): Sort dictionary keys alphabetically (default: False)

**Returns:**

- YAML string

**Examples:**

```python
# Custom indentation
yaml_str = fast_yaml.safe_dump(data, indent=4)

# Limit line width
yaml_str = fast_yaml.safe_dump(data, width=120)

# Explicit document markers
yaml_str = fast_yaml.safe_dump(data, explicit_start=True)
# Output: ---\nname: example\n...

# Sort keys
yaml_str = fast_yaml.safe_dump(data, sort_keys=True)
```

#### `safe_dump_all(documents, **kwargs)` - Serialize Multiple Documents

Serializes multiple Python objects as multi-document YAML.

```python
import fast_yaml

docs = [
    {'name': 'doc1', 'value': 100},
    {'name': 'doc2', 'value': 200}
]

yaml_str = fast_yaml.safe_dump_all(docs)
print(yaml_str)
```

**Output:**

```yaml
---
name: doc1
value: 100
---
name: doc2
value: 200
```

**Parameters:**

Same as `safe_dump()`, plus:

- `documents` (Iterable): Sequence of Python objects

**Returns:**

- Multi-document YAML string

### PyYAML-Compatible API

For drop-in replacement of PyYAML:

```python
import fast_yaml

# Load with explicit Loader
data = fast_yaml.load(yaml_str, Loader=fast_yaml.SafeLoader)

# Dump with explicit Dumper
yaml_str = fast_yaml.dump(data, Dumper=fast_yaml.SafeDumper)

# Load all documents
for doc in fast_yaml.load_all(yaml_str, Loader=fast_yaml.SafeLoader):
    print(doc)

# Dump all documents
yaml_str = fast_yaml.dump_all(docs, Dumper=fast_yaml.SafeDumper)
```

**Note:** `SafeLoader` and `SafeDumper` are provided for PyYAML compatibility. Direct use of `safe_load()` and `safe_dump()` is recommended.

## Linting API

### `lint(yaml_str)` - Validate YAML with Diagnostics

Performs comprehensive validation and returns detailed diagnostics.

```python
from fast_yaml._core.lint import lint

yaml_str = """
database:
  host: localhost
  port: 5432
database:
  host: remote
"""

diagnostics = lint(yaml_str)

for diag in diagnostics:
    print(f"{diag.severity}: {diag.message}")
    print(f"  Line {diag.span.start.line}, Column {diag.span.start.column}")
```

**Output:**

```
error: duplicate key 'database' found
  Line 5, Column 1
```

**Diagnostic Object:**

```python
@dataclass
class Diagnostic:
    severity: str  # "error", "warning", "info"
    message: str
    span: Span

@dataclass
class Span:
    start: Position
    end: Position

@dataclass
class Position:
    line: int     # 1-based line number
    column: int   # 1-based column number
    offset: int   # 0-based byte offset
```

**Examples:**

```python
# Validate configuration file
def validate_config(config_path: str) -> bool:
    with open(config_path) as f:
        yaml_str = f.read()

    diagnostics = lint(yaml_str)

    if not diagnostics:
        print("✓ Configuration is valid")
        return True

    for diag in diagnostics:
        print(f"✗ {diag.severity.upper()}: {diag.message}")
        print(f"  at {config_path}:{diag.span.start.line}:{diag.span.start.column}")

    return False

# CI/CD validation
import sys

if not validate_config("config.yaml"):
    sys.exit(1)
```

## Parallel Processing API

### `parse_parallel(yaml_str, config=None)` - Parse Documents in Parallel

Parses multi-document YAML streams using parallel workers.

```python
from fast_yaml._core.parallel import parse_parallel, ParallelConfig

# Multi-document YAML
yaml_str = """
---
name: doc1
data: [1, 2, 3]
---
name: doc2
data: [4, 5, 6]
---
name: doc3
data: [7, 8, 9]
"""

# Parse with 4 workers
config = ParallelConfig(thread_count=4)
documents = parse_parallel(yaml_str, config)

for doc in documents:
    print(doc)
```

**ParallelConfig:**

```python
@dataclass
class ParallelConfig:
    thread_count: int = os.cpu_count()      # Number of workers
    max_input_size: int = 100 * 1024 * 1024 # Max size (100MB)
```

**Parameters:**

- `yaml_str` (str): Multi-document YAML string
- `config` (ParallelConfig | None): Configuration (default: auto-detect cores)

**Returns:**

- List of parsed documents

**Raises:**

- `YAMLError`: On syntax errors
- `ValueError`: If input exceeds `max_input_size`

**Performance Notes:**

- Best for 10+ documents
- 3-6x speedup on 4-8 core systems
- Overhead for small documents (<1KB)

**Examples:**

```python
# Process large configuration sets
config = ParallelConfig(
    thread_count=8,
    max_input_size=500 * 1024 * 1024  # 500MB
)

with open('large-config.yaml') as f:
    yaml_str = f.read()

documents = parse_parallel(yaml_str, config)
print(f"Parsed {len(documents)} documents")

# Auto-detect optimal workers
documents = parse_parallel(yaml_str)  # Uses os.cpu_count()
```

## Type Mappings

Python types map to YAML as follows:

| Python Type | YAML Representation |
|-------------|---------------------|
| `None` | `null` or `~` |
| `bool` | `true` / `false` |
| `int` | Integer literal |
| `float` | Float literal |
| `str` | String (quoted if needed) |
| `list` | Sequence (`- item`) |
| `dict` | Mapping (`key: value`) |
| `datetime.date` | ISO 8601 date |
| `datetime.datetime` | ISO 8601 timestamp |

**Examples:**

```python
import fast_yaml
from datetime import datetime, date

data = {
    'null_value': None,
    'boolean': True,
    'integer': 42,
    'float': 3.14,
    'string': 'hello',
    'list': [1, 2, 3],
    'nested': {'key': 'value'},
    'date': date(2025, 1, 15),
    'timestamp': datetime(2025, 1, 15, 14, 30, 0)
}

yaml_str = fast_yaml.safe_dump(data)
print(yaml_str)
```

**Output:**

```yaml
null_value: null
boolean: true
integer: 42
float: 3.14
string: hello
list:
  - 1
  - 2
  - 3
nested:
  key: value
date: 2025-01-15
timestamp: 2025-01-15T14:30:00
```

## Format Conversion

### JSON to YAML

Convert JSON to YAML using standard library `json` module with fast-yaml:

```python
import json
import fast_yaml

# Load JSON from file
with open('config.json') as f:
    data = json.load(f)

# Convert to YAML
yaml_str = fast_yaml.safe_dump(data, indent=2)

# Save to file
with open('config.yaml', 'w') as f:
    f.write(yaml_str)
```

**One-liner conversion:**

```python
import json
import fast_yaml

# JSON → YAML
yaml_str = fast_yaml.safe_dump(json.loads(open('config.json').read()))

# YAML → JSON
json_str = json.dumps(fast_yaml.safe_load(open('config.yaml').read()), indent=2)
```

### YAML to JSON

```python
import json
import fast_yaml

# Load YAML
with open('config.yaml') as f:
    data = fast_yaml.safe_load(f)

# Convert to JSON
json_str = json.dumps(data, indent=2)

# Save to file
with open('config.json', 'w') as f:
    f.write(json_str)
```

### Conversion Helper Functions

```python
import json
import fast_yaml
from pathlib import Path

def yaml_to_json(yaml_path: str, json_path: str, indent: int = 2) -> None:
    """Convert YAML file to JSON."""
    with open(yaml_path) as f:
        data = fast_yaml.safe_load(f)
    with open(json_path, 'w') as f:
        json.dump(data, f, indent=indent)

def json_to_yaml(json_path: str, yaml_path: str, indent: int = 2) -> None:
    """Convert JSON file to YAML."""
    with open(json_path) as f:
        data = json.load(f)
    yaml_str = fast_yaml.safe_dump(data, indent=indent)
    with open(yaml_path, 'w') as f:
        f.write(yaml_str)

# Usage
yaml_to_json('config.yaml', 'config.json')
json_to_yaml('data.json', 'data.yaml')
```

### Batch Conversion

```python
import json
import fast_yaml
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor

def convert_json_to_yaml(json_file: Path) -> None:
    """Convert single JSON file to YAML."""
    yaml_file = json_file.with_suffix('.yaml')
    with open(json_file) as f:
        data = json.load(f)
    yaml_str = fast_yaml.safe_dump(data)
    with open(yaml_file, 'w') as f:
        f.write(yaml_str)
    print(f"Converted {json_file} → {yaml_file}")

def batch_convert_json_to_yaml(directory: str) -> None:
    """Convert all JSON files in directory to YAML."""
    json_files = list(Path(directory).rglob("*.json"))

    with ThreadPoolExecutor(max_workers=8) as executor:
        executor.map(convert_json_to_yaml, json_files)

    print(f"Converted {len(json_files)} files")

# Usage
batch_convert_json_to_yaml("./configs")
```

## Error Handling

### Exception Hierarchy

```python
fast_yaml.YAMLError
└── fast_yaml.YAMLSyntaxError
```

### Handling Parse Errors

```python
import fast_yaml

try:
    data = fast_yaml.safe_load("invalid: yaml: syntax:")
except fast_yaml.YAMLError as e:
    print(f"YAML Error: {e}")
    print(f"Line: {e.line}")
    print(f"Column: {e.column}")
```

### Validation Pattern

```python
def load_config(path: str) -> dict:
    """Load and validate YAML configuration."""
    try:
        with open(path) as f:
            yaml_str = f.read()

        # Lint first
        diagnostics = lint(yaml_str)
        if diagnostics:
            errors = [d for d in diagnostics if d.severity == "error"]
            if errors:
                raise ValueError(f"Configuration has {len(errors)} errors")

        # Parse
        return fast_yaml.safe_load(yaml_str)

    except fast_yaml.YAMLError as e:
        raise ValueError(f"Invalid YAML: {e}") from e
    except FileNotFoundError:
        raise ValueError(f"Configuration file not found: {path}")
```

## Advanced Usage

### Stream Processing

```python
import fast_yaml

# Process large file without loading entire content
def process_large_yaml(path: str):
    with open(path) as f:
        for doc in fast_yaml.safe_load_all(f):
            # Process each document individually
            process_document(doc)
            # Memory is freed after each iteration
```

### Configuration Validation

```python
import fast_yaml
from typing import TypedDict

class DatabaseConfig(TypedDict):
    host: str
    port: int
    database: str

def load_validated_config(path: str) -> DatabaseConfig:
    """Load and validate configuration against schema."""
    with open(path) as f:
        config = fast_yaml.safe_load(f)

    # Validate required fields
    required = {'host', 'port', 'database'}
    if not all(k in config for k in required):
        missing = required - config.keys()
        raise ValueError(f"Missing required fields: {missing}")

    # Type validation
    if not isinstance(config['port'], int):
        raise ValueError("port must be an integer")

    return config
```

### Batch File Processing

```python
import fast_yaml
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor

def validate_yaml_file(path: Path) -> tuple[Path, list]:
    """Validate single YAML file, return diagnostics."""
    yaml_str = path.read_text()
    diagnostics = lint(yaml_str)
    return (path, diagnostics)

def validate_project_yamls(project_dir: str) -> dict:
    """Validate all YAML files in project directory."""
    yaml_files = list(Path(project_dir).rglob("*.yaml"))

    results = {}
    with ThreadPoolExecutor(max_workers=8) as executor:
        for path, diagnostics in executor.map(validate_yaml_file, yaml_files):
            if diagnostics:
                results[str(path)] = diagnostics

    return results

# Usage
errors = validate_project_yamls("./project")
if errors:
    print(f"Found errors in {len(errors)} files")
    for path, diagnostics in errors.items():
        print(f"\n{path}:")
        for diag in diagnostics:
            print(f"  {diag.severity}: {diag.message}")
```

## Migration from PyYAML

### Drop-in Replacement

```python
# Before (PyYAML)
import yaml
data = yaml.safe_load(yaml_str)
yaml_str = yaml.safe_dump(data)

# After (fast-yaml)
import fast_yaml as yaml
data = yaml.safe_load(yaml_str)
yaml_str = yaml.safe_dump(data)
```

### Handling YAML 1.2.2 Differences

```python
# PyYAML (YAML 1.1) behavior
import yaml as pyyaml
data = pyyaml.safe_load("enabled: yes")
print(data)  # {'enabled': True}

# fast-yaml (YAML 1.2.2) behavior
import fast_yaml
data = fast_yaml.safe_load("enabled: yes")
print(data)  # {'enabled': 'yes'}

# Workaround: use explicit booleans
data = fast_yaml.safe_load("enabled: true")
print(data)  # {'enabled': True}
```

See [yaml-spec.md](yaml-spec.md) for complete migration guide.

## Performance Benchmarks

Compared to PyYAML:

| Operation | Small Files (<10KB) | Medium Files (100KB) | Large Files (>1MB) |
|-----------|---------------------|----------------------|--------------------|
| Parse | 1.3x faster | 1.4x faster | 1.5x faster |
| Dump | 1.2x faster | 1.3x faster | 1.4x faster |
| Parallel parse | N/A | 3-4x faster | 5-6x faster |

**Note:** Benchmarks on Python 3.11, comparing against PyYAML with C extensions.

## Thread Safety

fast-yaml is thread-safe for all operations:

```python
from concurrent.futures import ThreadPoolExecutor
import fast_yaml

def process_config(config_str: str):
    return fast_yaml.safe_load(config_str)

# Safe to use across threads
with ThreadPoolExecutor(max_workers=10) as executor:
    configs = executor.map(process_config, yaml_strings)
```
