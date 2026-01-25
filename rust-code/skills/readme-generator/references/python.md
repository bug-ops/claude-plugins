# Python README Template

> [!IMPORTANT]
> Python version badge is required. Users must know if package works with their Python version.

## Structure

```markdown
# package-name

[![PyPI](https://img.shields.io/pypi/v/{package})](https://pypi.org/project/{package})
[![Python](https://img.shields.io/pypi/pyversions/{package})](https://pypi.org/project/{package})
[![CI](https://img.shields.io/github/actions/workflow/status/{owner}/{repo}/ci.yml)](https://github.com/{owner}/{repo}/actions)
[![License](https://img.shields.io/pypi/l/{package})](LICENSE)
[![Documentation](https://img.shields.io/badge/docs-Read%20the%20Docs-blue)](https://{package}.readthedocs.io)

One-line description from pyproject.toml.

## Installation

\`\`\`bash
pip install {package}
\`\`\`

### With optional dependencies

\`\`\`bash
pip install {package}[extra1,extra2]
\`\`\`

### Alternative package managers

\`\`\`bash
# Poetry
poetry add {package}

# Pipenv
pipenv install {package}

# Conda (if available)
conda install -c conda-forge {package}
\`\`\`

> [!TIP]
> Use `uv pip install {package}` for faster installation (10-100x faster than pip).

## Quick Start

\`\`\`python
from {package} import Thing

thing = Thing()
result = thing.do_something()
print(result)
\`\`\`

## Usage

### Basic Example

\`\`\`python
from {package} import create_thing

# Create instance with options
thing = create_thing(
    option1="value",
    option2=True,
)

# Use the thing
result = thing.process(data)
\`\`\`

### Async Example

\`\`\`python
import asyncio
from {package} import AsyncThing

async def main():
    async with AsyncThing() as thing:
        result = await thing.do_async()
    return result

asyncio.run(main())
\`\`\`

> [!NOTE]
> Use `async with` for proper resource cleanup. The context manager handles connection pooling.

## API Reference

### `Thing`

Main class for doing things.

\`\`\`python
from {package} import Thing

thing = Thing(
    option1: str = "default",
    option2: bool = False,
)
\`\`\`

**Parameters:**

| Name | Type | Default | Description |
|------|------|---------|-------------|
| `option1` | `str` | `"default"` | Description |
| `option2` | `bool` | `False` | Description |

**Methods:**

- `do_something() -> Result` - Does something
- `process(data: Data) -> Output` - Processes data

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `{PACKAGE}_API_KEY` | API key | None |
| `{PACKAGE}_DEBUG` | Enable debug mode | `false` |

### Configuration File

\`\`\`python
# config.py or pyproject.toml
[tool.{package}]
option1 = "value"
option2 = true
\`\`\`

## Requirements

> [!IMPORTANT]
> Python 3.8 reaches end-of-life soon. This package supports Python 3.9+.

- Python >= 3.9

## License

[{license}](LICENSE)
```

## Python-Specific Requirements

### Python Version Support

Always show supported Python versions:

```markdown
[![Python](https://img.shields.io/pypi/pyversions/{package})](https://pypi.org/project/{package})
```

And in requirements:

```markdown
## Requirements

- Python >= 3.9
```

### Installation with Extras

Document optional dependencies:

```markdown
## Installation

\`\`\`bash
# Basic installation
pip install {package}

# With async support
pip install {package}[async]

# With all extras
pip install {package}[all]

# For development
pip install {package}[dev]
\`\`\`

### Available Extras

| Extra | Description | Includes |
|-------|-------------|----------|
| `async` | Async support | aiohttp, asyncio |
| `cli` | CLI interface | click, rich |
| `all` | All features | Everything |
```

### Package Managers

Show pip first (standard), then alternatives:

```markdown
\`\`\`bash
# pip (recommended)
pip install {package}

# Poetry
poetry add {package}

# Pipenv  
pipenv install {package}

# uv (fast alternative)
uv pip install {package}

# Conda (if on conda-forge)
conda install -c conda-forge {package}
\`\`\`
```

### Type Hints

Document type hint support:

```markdown
## Type Hints

This package is fully typed. Enable type checking:

\`\`\`python
from {package} import Thing
from {package}.types import ThingConfig, Result

def process(config: ThingConfig) -> Result:
    thing = Thing(config)
    return thing.run()
\`\`\`

Type stubs are included in the package.
```

For inline type annotations:

```python
from {package} import Thing

thing: Thing = Thing()
result: str = thing.do_something()
```

### Async/Sync Variants

> [!TIP]
> If package supports both sync and async, show examples side-by-side. Users need to see the difference immediately.

If both async and sync APIs exist:

```markdown
## Async Support

### Synchronous API

\`\`\`python
from {package} import Client

client = Client()
result = client.get_data()
\`\`\`

### Asynchronous API

\`\`\`python
from {package} import AsyncClient

async with AsyncClient() as client:
    result = await client.get_data()
\`\`\`
```

### Context Managers

Show proper resource management:

```python
# Recommended - with context manager
with Thing() as thing:
    result = thing.process()

# Or async
async with AsyncThing() as thing:
    result = await thing.process()
```

### Documentation Links

Link to documentation:

```markdown
## Documentation

- [Quick Start](https://{package}.readthedocs.io/quickstart/)
- [API Reference](https://{package}.readthedocs.io/api/)
- [Examples](https://{package}.readthedocs.io/examples/)
```

### CLI Usage

If package includes CLI:

```markdown
## CLI

\`\`\`bash
# After installation
{package} --help

# Common commands
{package} init
{package} run --config config.yaml
{package} version
\`\`\`
```

### Virtual Environment

Recommend virtual environments:

```markdown
## Installation

\`\`\`bash
# Create virtual environment
python -m venv venv
source venv/bin/activate  # Linux/macOS
# or
.\venv\Scripts\activate  # Windows

# Install package
pip install {package}
\`\`\`
```

## Badge Priority for Python

1. PyPI version (required)
2. Python versions (required)
3. CI status (recommended)
4. License (required)
5. Documentation (if Read the Docs)
6. Downloads (optional)
7. Code coverage (optional)

## PyPI Integration

Show correct import vs package name if different:

```markdown
## Installation

\`\`\`bash
pip install {pypi-name}
\`\`\`

## Usage

\`\`\`python
import {import_name}  # Note: import name differs from package name
\`\`\`
```

## Development Installation

For contributors:

```markdown
## Development

\`\`\`bash
# Clone repository
git clone https://github.com/{owner}/{repo}
cd {repo}

# Install with dev dependencies
pip install -e ".[dev]"

# Run tests
pytest

# Run linters
ruff check .
mypy .
\`\`\`
```

## pyproject.toml Integration

Modern Python uses pyproject.toml:

```markdown
## Configuration

Configure in `pyproject.toml`:

\`\`\`toml
[tool.{package}]
option1 = "value"
option2 = true

[tool.{package}.subsection]
nested = "value"
\`\`\`
```

## Error Handling

Show exception handling:

```python
from {package} import Thing, ThingError, ValidationError

try:
    thing = Thing()
    result = thing.process(data)
except ValidationError as e:
    print(f"Invalid input: {e}")
except ThingError as e:
    print(f"Processing failed: {e}")
```
