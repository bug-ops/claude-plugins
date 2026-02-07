# YAML 1.2.2 Specification Reference

Understanding YAML 1.2.2 differences and migration from YAML 1.1 (PyYAML, js-yaml).

## Overview

fast-yaml implements **YAML 1.2.2 specification**, while many popular YAML libraries (PyYAML, js-yaml) implement **YAML 1.1**. This guide covers the key differences and migration strategies.

> [!IMPORTANT]
> YAML 1.2.2 is the current specification (2021). YAML 1.1 is from 2005 and has several ambiguities and inconsistencies that 1.2.2 resolves.

## Critical Differences

### Boolean Values

**YAML 1.1 (PyYAML, js-yaml):**

```yaml
# All of these parse as boolean true
enabled: yes
enabled: Yes
enabled: YES
enabled: on
enabled: On
enabled: ON
enabled: true
enabled: True
enabled: TRUE

# All of these parse as boolean false
enabled: no
enabled: No
enabled: NO
enabled: off
enabled: Off
enabled: OFF
enabled: false
enabled: False
enabled: FALSE
```

**YAML 1.2.2 (fast-yaml):**

```yaml
# Only these parse as boolean
enabled: true   # boolean true
enabled: false  # boolean false

# These are STRINGS
enabled: yes    # string "yes"
enabled: no     # string "no"
enabled: on     # string "on"
enabled: off    # string "off"
enabled: Yes    # string "Yes"
enabled: YES    # string "YES"
```

**Migration:**

```yaml
# ❌ Old (YAML 1.1)
debug: yes
verbose: no
ssl_enabled: on

# ✅ New (YAML 1.2.2)
debug: true
verbose: false
ssl_enabled: true
```

**Why this changed:** YAML 1.1's boolean rules were locale-dependent and confusing. Different languages have different words for yes/no, leading to inconsistent behavior.

### Octal Numbers

**YAML 1.1 (PyYAML, js-yaml):**

```yaml
permissions: 0644   # Parses as 420 (octal)
value: 014          # Parses as 12 (octal)
```

**YAML 1.2.2 (fast-yaml):**

```yaml
permissions: 0644   # Parses as 644 (decimal)
value: 014          # Parses as 14 (decimal)

# Use explicit prefix for octal
permissions: 0o644  # Parses as 420 (octal)
value: 0o14         # Parses as 12 (octal)
```

**Migration:**

```yaml
# ❌ Old (YAML 1.1)
file_mode: 0755
umask: 022

# ✅ New (YAML 1.2.2)
file_mode: 0o755
umask: 0o22
```

**Why this changed:** Leading zeros are ambiguous. JSON treats them as syntax errors, and many programming languages use `0o` prefix for clarity.

### Number Formats

**YAML 1.2.2 explicit prefixes:**

| Prefix | Base | Example | Decimal Value |
|--------|------|---------|---------------|
| `0x` | Hexadecimal | `0xFF` | 255 |
| `0o` | Octal | `0o777` | 511 |
| `0b` | Binary | `0b1010` | 10 |
| (none) | Decimal | `1234` | 1234 |

**Examples:**

```yaml
# YAML 1.2.2
hex_color: 0xFF00FF    # 16711935
permissions: 0o755     # 493
flags: 0b11010         # 26
count: 1234            # 1234

# Floats
pi: 3.14159
scientific: 1.23e-4
infinity: .inf
not_a_number: .nan
```

## Additional Differences

### Merge Keys

**YAML 1.1:** Supported `<<` merge key

```yaml
# YAML 1.1 (PyYAML)
defaults: &defaults
  host: localhost
  port: 5432

production:
  <<: *defaults
  host: prod.example.com
# Result: { host: 'prod.example.com', port: 5432 }
```

**YAML 1.2.2:** Merge keys are **not in the spec** but commonly supported

```yaml
# YAML 1.2.2 (fast-yaml)
# Merge keys work but are not standardized
defaults: &defaults
  host: localhost
  port: 5432

production:
  <<: *defaults  # Supported in fast-yaml
  host: prod.example.com
```

> [!WARNING]
> Merge keys (`<<`) are a common extension but not part of YAML 1.2.2 spec. fast-yaml supports them for compatibility, but prefer explicit keys for portability.

**Migration:** Use explicit keys for maximum compatibility

```yaml
# ✅ Recommended (works everywhere)
defaults: &defaults
  host: localhost
  port: 5432

production:
  host: prod.example.com
  port: 5432  # Explicit
```

### Timestamp Format

**YAML 1.1:** Very permissive timestamp parsing

```yaml
# All parse as dates/timestamps in YAML 1.1
date: 2025-01-15
datetime: 2025-01-15 14:30:00
iso8601: 2025-01-15T14:30:00Z
space_separated: 2025-01-15 14:30:00
```

**YAML 1.2.2:** Stricter ISO 8601 format

```yaml
# YAML 1.2.2 requires ISO 8601 format
date: 2025-01-15
datetime: 2025-01-15T14:30:00Z
datetime_with_offset: 2025-01-15T14:30:00+00:00

# These are STRINGS (not timestamps)
space_separated: 2025-01-15 14:30:00  # string
slash_format: 01/15/2025              # string
```

**Migration:**

```yaml
# ❌ Old (YAML 1.1)
created_at: 2025-01-15 14:30:00

# ✅ New (YAML 1.2.2)
created_at: 2025-01-15T14:30:00Z
```

### Null Values

**Both YAML 1.1 and 1.2.2 support multiple null representations:**

```yaml
# All represent null/None
value1: null
value2: ~
value3:        # empty value
value4: Null
value5: NULL
```

**Migration:** No changes needed, but `null` is most explicit

```yaml
# ✅ Recommended
database_password: null
optional_field: ~
```

## Type Coercion Differences

### Unquoted Strings

**YAML 1.1:** Aggressive type coercion

```yaml
version: 1.0         # number (float)
enabled: yes         # boolean
count: 014           # number (octal = 12)
```

**YAML 1.2.2:** More conservative

```yaml
version: 1.0         # number (float)
enabled: yes         # STRING "yes"
count: 014           # number (decimal = 14)
```

**Migration:** Use explicit types

```yaml
# Use quotes for strings that might be confused with other types
version: "1.0"       # string
semantic_version: "1.0.0"  # string
zip_code: "01234"    # string
```

### Empty Values

**Both versions:**

```yaml
# All represent empty string
empty1: ""
empty2: ''
empty3:

# Explicit null
null_value: null
```

## Migration Checklist

### From PyYAML (Python)

1. **Replace boolean keywords:**
   ```yaml
   # Before
   enabled: yes
   debug: no

   # After
   enabled: true
   debug: false
   ```

2. **Fix octal numbers:**
   ```yaml
   # Before
   permissions: 0755

   # After
   permissions: 0o755
   ```

3. **Update timestamps:**
   ```yaml
   # Before
   created: 2025-01-15 14:30:00

   # After
   created: 2025-01-15T14:30:00Z
   ```

4. **Test edge cases:**
   ```python
   import fast_yaml

   # Verify boolean handling
   assert fast_yaml.safe_load("enabled: yes") == {"enabled": "yes"}
   assert fast_yaml.safe_load("enabled: true") == {"enabled": True}

   # Verify octal handling
   assert fast_yaml.safe_load("perms: 0644") == {"perms": 644}
   assert fast_yaml.safe_load("perms: 0o644") == {"perms": 420}
   ```

### From js-yaml (JavaScript/TypeScript)

1. **Same boolean and octal fixes as above**

2. **Update type assertions:**
   ```typescript
   // Before (js-yaml)
   import yaml from 'js-yaml';
   const config = yaml.load(yamlStr) as Config;

   // After (fast-yaml)
   import { safeLoad } from 'fastyaml-rs';
   const config = safeLoad(yamlStr) as Config;

   // Add runtime validation for booleans
   if (typeof config.enabled === 'string') {
     config.enabled = config.enabled === 'true';
   }
   ```

3. **Test compatibility:**
   ```typescript
   import { safeLoad } from 'fastyaml-rs';

   // Verify boolean handling
   expect(safeLoad('enabled: yes')).toEqual({ enabled: 'yes' });
   expect(safeLoad('enabled: true')).toEqual({ enabled: true });

   // Verify octal handling
   expect(safeLoad('perms: 0644')).toEqual({ perms: 644 });
   expect(safeLoad('perms: 0o644')).toEqual({ perms: 420 });
   ```

## Validation Tools

### Automated Migration Script (Python)

```python
#!/usr/bin/env python3
"""Convert YAML 1.1 files to YAML 1.2.2 compatible format."""

import re
import sys
from pathlib import Path

def migrate_yaml_content(content: str) -> str:
    """Migrate YAML content from 1.1 to 1.2.2 format."""

    # Replace yes/no with true/false (but not in strings)
    # This is a simple heuristic - may need manual review
    content = re.sub(r'^(\s+\w+):\s+(yes|Yes|YES)\s*$',
                    r'\1: true', content, flags=re.MULTILINE)
    content = re.sub(r'^(\s+\w+):\s+(no|No|NO)\s*$',
                    r'\1: false', content, flags=re.MULTILINE)
    content = re.sub(r'^(\s+\w+):\s+(on|On|ON)\s*$',
                    r'\1: true', content, flags=re.MULTILINE)
    content = re.sub(r'^(\s+\w+):\s+(off|Off|OFF)\s*$',
                    r'\1: false', content, flags=re.MULTILINE)

    # Fix octal numbers (simple cases)
    # Match: key: 0644 -> key: 0o644
    content = re.sub(r'^(\s+\w+):\s+0([0-7]{3})\s*$',
                    r'\1: 0o\2', content, flags=re.MULTILINE)

    # Fix timestamps (space to T)
    # Match: 2025-01-15 14:30:00 -> 2025-01-15T14:30:00
    content = re.sub(r'(\d{4}-\d{2}-\d{2})\s+(\d{2}:\d{2}:\d{2})',
                    r'\1T\2', content)

    return content

def migrate_file(path: Path, in_place: bool = False) -> None:
    """Migrate a YAML file to 1.2.2 format."""
    content = path.read_text()
    migrated = migrate_yaml_content(content)

    if in_place:
        path.write_text(migrated)
        print(f"✓ Migrated {path}")
    else:
        print(migrated)

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: migrate_yaml.py <file.yaml> [--in-place]")
        sys.exit(1)

    path = Path(sys.argv[1])
    in_place = '--in-place' in sys.argv

    migrate_file(path, in_place)
```

**Usage:**

```bash
# Preview changes
python migrate_yaml.py config.yaml

# Apply changes
python migrate_yaml.py config.yaml --in-place
```

### Validation Script

```python
#!/usr/bin/env python3
"""Validate YAML files for 1.1 vs 1.2.2 compatibility issues."""

import fast_yaml
import yaml as pyyaml  # Install PyYAML for comparison
from pathlib import Path

def compare_parsers(yaml_str: str) -> dict:
    """Compare PyYAML (1.1) vs fast-yaml (1.2.2) parsing."""
    try:
        pyyaml_result = pyyaml.safe_load(yaml_str)
        fastyaml_result = fast_yaml.safe_load(yaml_str)

        if pyyaml_result != fastyaml_result:
            return {
                'compatible': False,
                'pyyaml': pyyaml_result,
                'fastyaml': fastyaml_result
            }
        return {'compatible': True}
    except Exception as e:
        return {'error': str(e)}

# Test cases
test_cases = [
    ('enabled: yes', 'Boolean keyword'),
    ('perms: 0644', 'Octal number'),
    ('date: 2025-01-15 14:30:00', 'Timestamp'),
]

for yaml_str, description in test_cases:
    result = compare_parsers(yaml_str)
    if not result.get('compatible', True):
        print(f"⚠️  {description}:")
        print(f"   PyYAML: {result['pyyaml']}")
        print(f"   fast-yaml: {result['fastyaml']}")
```

## Best Practices for YAML 1.2.2

1. **Use explicit types:**
   ```yaml
   # ✅ Clear and unambiguous
   enabled: true
   version: "1.0.0"
   permissions: 0o755
   ```

2. **Avoid deprecated syntax:**
   ```yaml
   # ❌ Avoid
   enabled: yes
   perms: 0644

   # ✅ Use
   enabled: true
   perms: 0o755
   ```

3. **Quote strings that look like other types:**
   ```yaml
   # ✅ Explicit strings
   version: "2.0"
   zip_code: "01234"
   phone: "+1-555-0100"
   ```

4. **Use ISO 8601 for timestamps:**
   ```yaml
   # ✅ Standard format
   created_at: 2025-01-15T14:30:00Z
   updated_at: 2025-01-15T14:30:00+00:00
   ```

5. **Validate with linting:**
   ```bash
   # Use fast-yaml to validate
   fy lint config.yaml
   ```

## References

- **YAML 1.2.2 Specification:** https://yaml.org/spec/1.2.2/
- **YAML 1.1 Specification:** https://yaml.org/spec/1.1/
- **Migration Guide:** https://github.com/yaml/yaml-spec/wiki/YAML-1.2-Migration
- **Type Repository:** https://yaml.org/type/

## Common Gotchas

### Country Codes

```yaml
# ❌ Norway's country code (NO) becomes boolean false in YAML 1.1
country: NO

# ✅ Always quote country codes
country: "NO"
```

### Version Numbers

```yaml
# ❌ 1.0 becomes float
version: 1.0

# ✅ Quote version strings
version: "1.0"
version: "1.0.0"
```

### Leading Zeros

```yaml
# ❌ Octal in YAML 1.1
zip_code: 01234

# ✅ Quote numbers with leading zeros
zip_code: "01234"
```

### Configuration Switches

```yaml
# ❌ "off" becomes boolean in YAML 1.1
state: off

# ✅ Use explicit booleans or quote
state: false
state: "off"  # If you mean the string "off"
```
