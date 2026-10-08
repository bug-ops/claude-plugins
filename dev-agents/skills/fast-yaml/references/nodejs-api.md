# Node.js API Reference

Complete reference for using fast-yaml in TypeScript and JavaScript applications.

## Installation

```bash
npm install fastyaml-rs
```

**Requirements:**

- Node.js 20.0 or later
- npm 9.0 or later

**Verify installation:**

```bash
node -e "const fy = require('fastyaml-rs'); console.log('fast-yaml loaded successfully')"
```

## Module Imports

### CommonJS

```javascript
const { safeLoad, safeDump, safeLoadAll, safeDumpAll } = require('fastyaml-rs');
```

### ES Modules

```typescript
import { safeLoad, safeDump, safeLoadAll, safeDumpAll } from 'fastyaml-rs';
```

### TypeScript

```typescript
import {
  safeLoad,
  safeDump,
  safeLoadAll,
  safeDumpAll,
  DumpOptions,
  YAMLError
} from 'fastyaml-rs';
```

## Core API

### Loading YAML

#### `safeLoad(input: string): any`

Parses a YAML string into a JavaScript object.

```typescript
import { safeLoad } from 'fastyaml-rs';

const yamlStr = `
name: example
version: 1.0.0
enabled: true
features:
  - fast
  - safe
`;

const data = safeLoad(yamlStr);
console.log(data);
// {
//   name: 'example',
//   version: '1.0.0',
//   enabled: true,
//   features: ['fast', 'safe']
// }
```

**Parameters:**

- `input` (string): YAML string to parse

**Returns:**

- JavaScript object, array, string, number, boolean, or null

**Throws:**

- `YAMLError`: On syntax errors or invalid YAML

**Examples:**

```typescript
// Load from file (Node.js)
import { readFileSync } from 'fs';
import { safeLoad } from 'fastyaml-rs';

const yamlStr = readFileSync('config.yaml', 'utf-8');
const config = safeLoad(yamlStr);

// Error handling
try {
  const data = safeLoad('invalid: yaml: syntax:');
} catch (error) {
  if (error instanceof YAMLError) {
    console.error(`YAML Error at line ${error.line}: ${error.message}`);
  }
}
```

#### `safeLoadAll(input: string): any[]`

Parses multiple YAML documents separated by `---`.

```typescript
import { safeLoadAll } from 'fastyaml-rs';

const yamlStr = `
---
name: doc1
value: 100
---
name: doc2
value: 200
`;

const documents = safeLoadAll(yamlStr);
console.log(documents);
// [
//   { name: 'doc1', value: 100 },
//   { name: 'doc2', value: 200 }
// ]
```

**Parameters:**

- `input` (string): Multi-document YAML string

**Returns:**

- Array of JavaScript objects

**Throws:**

- `YAMLError`: On syntax errors

### Dumping YAML

#### `safeDump(data: any, options?: DumpOptions): string`

Converts a JavaScript object to YAML string.

```typescript
import { safeDump } from 'fastyaml-rs';

const data = {
  name: 'example',
  version: '1.0.0',
  features: ['fast', 'safe', 'spec-compliant']
};

const yamlStr = safeDump(data);
console.log(yamlStr);
```

**Output:**

```yaml
name: example
version: 1.0.0
features:
  - fast
  - safe
  - spec-compliant
```

**DumpOptions:**

```typescript
interface DumpOptions {
  indent?: number;        // Indentation spaces (default: 2)
  width?: number;         // Max line width (default: 80)
  explicitStart?: boolean; // Add --- marker (default: false)
  explicitEnd?: boolean;   // Add ... marker (default: false)
  sortKeys?: boolean;      // Sort object keys (default: false)
}
```

**Examples:**

```typescript
// Custom indentation
const yaml = safeDump(data, { indent: 4 });

// Limit line width
const yaml = safeDump(data, { width: 120 });

// Explicit document markers
const yaml = safeDump(data, { explicitStart: true });
// Output: ---\nname: example\n...

// Sort keys alphabetically
const yaml = safeDump(data, { sortKeys: true });

// Combine options
const yaml = safeDump(data, {
  indent: 4,
  width: 120,
  explicitStart: true,
  sortKeys: true
});
```

#### `safeDumpAll(documents: any[], options?: DumpOptions): string`

Serializes multiple JavaScript objects as multi-document YAML.

```typescript
import { safeDumpAll } from 'fastyaml-rs';

const documents = [
  { name: 'doc1', value: 100 },
  { name: 'doc2', value: 200 }
];

const yamlStr = safeDumpAll(documents);
console.log(yamlStr);
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

- `documents` (any[]): Array of objects to serialize
- `options` (DumpOptions): Formatting options (same as `safeDump`)

**Returns:**

- Multi-document YAML string

## Type Mappings

JavaScript types map to YAML as follows:

| JavaScript Type | YAML Representation |
|-----------------|---------------------|
| `null` / `undefined` | `null` or `~` |
| `boolean` | `true` / `false` |
| `number` | Integer or float literal |
| `string` | String (quoted if needed) |
| `Array` | Sequence (`- item`) |
| `Object` | Mapping (`key: value`) |
| `Date` | ISO 8601 timestamp |

**Examples:**

```typescript
import { safeDump } from 'fastyaml-rs';

const data = {
  nullValue: null,
  undefinedValue: undefined,
  boolean: true,
  integer: 42,
  float: 3.14,
  string: 'hello',
  array: [1, 2, 3],
  nested: { key: 'value' },
  date: new Date('2025-01-15T14:30:00Z')
};

const yaml = safeDump(data);
console.log(yaml);
```

**Output:**

```yaml
nullValue: null
undefinedValue: null
boolean: true
integer: 42
float: 3.14
string: hello
array:
  - 1
  - 2
  - 3
nested:
  key: value
date: 2025-01-15T14:30:00.000Z
```

## Format Conversion

### JSON to YAML

Convert JSON to YAML using fast-yaml:

```typescript
import { safeDump } from 'fastyaml-rs';
import { readFileSync, writeFileSync } from 'fs';

// Load JSON from file
const jsonStr = readFileSync('config.json', 'utf-8');
const data = JSON.parse(jsonStr);

// Convert to YAML
const yaml = safeDump(data, { indent: 2 });

// Save to file
writeFileSync('config.yaml', yaml, 'utf-8');
```

**One-liner conversion:**

```typescript
import { safeLoad, safeDump } from 'fastyaml-rs';
import { readFileSync } from 'fs';

// JSON → YAML
const yaml = safeDump(JSON.parse(readFileSync('config.json', 'utf-8')));

// YAML → JSON
const json = JSON.stringify(safeLoad(readFileSync('config.yaml', 'utf-8')), null, 2);
```

### YAML to JSON

```typescript
import { safeLoad } from 'fastyaml-rs';
import { readFileSync, writeFileSync } from 'fs';

// Load YAML
const yamlStr = readFileSync('config.yaml', 'utf-8');
const data = safeLoad(yamlStr);

// Convert to JSON
const jsonStr = JSON.stringify(data, null, 2);

// Save to file
writeFileSync('config.json', jsonStr, 'utf-8');
```

### Conversion Helper Functions

```typescript
import { safeLoad, safeDump, DumpOptions } from 'fastyaml-rs';
import { readFileSync, writeFileSync } from 'fs';

function yamlToJson(
  yamlPath: string,
  jsonPath: string,
  indent: number = 2
): void {
  const data = safeLoad(readFileSync(yamlPath, 'utf-8'));
  writeFileSync(jsonPath, JSON.stringify(data, null, indent), 'utf-8');
}

function jsonToYaml(
  jsonPath: string,
  yamlPath: string,
  options?: DumpOptions
): void {
  const data = JSON.parse(readFileSync(jsonPath, 'utf-8'));
  const yaml = safeDump(data, options);
  writeFileSync(yamlPath, yaml, 'utf-8');
}

// Usage
yamlToJson('config.yaml', 'config.json');
jsonToYaml('data.json', 'data.yaml', { indent: 2, sortKeys: true });
```

### Batch Conversion

```typescript
import { safeLoad, safeDump } from 'fastyaml-rs';
import { readFileSync, writeFileSync } from 'fs';
import { glob } from 'glob';
import { resolve, parse } from 'path';

async function convertJsonToYaml(jsonFile: string): Promise<void> {
  const data = JSON.parse(readFileSync(jsonFile, 'utf-8'));
  const yaml = safeDump(data);

  const { dir, name } = parse(jsonFile);
  const yamlFile = resolve(dir, `${name}.yaml`);

  writeFileSync(yamlFile, yaml, 'utf-8');
  console.log(`Converted ${jsonFile} → ${yamlFile}`);
}

async function batchConvertJsonToYaml(pattern: string): Promise<void> {
  const files = await glob(pattern);

  await Promise.all(files.map(convertJsonToYaml));

  console.log(`Converted ${files.length} files`);
}

// Usage
batchConvertJsonToYaml('./configs/**/*.json');
```

### CLI Script

Create a conversion CLI tool:

```typescript
#!/usr/bin/env node
// yaml-json-convert.ts
import { safeLoad, safeDump } from 'fastyaml-rs';
import { readFileSync, writeFileSync } from 'fs';

const [,, direction, inputFile, outputFile] = process.argv;

if (!direction || !inputFile) {
  console.error('Usage: yaml-json-convert <yaml|json> <input> [output]');
  process.exit(1);
}

try {
  if (direction === 'json') {
    // YAML → JSON
    const data = safeLoad(readFileSync(inputFile, 'utf-8'));
    const json = JSON.stringify(data, null, 2);

    if (outputFile) {
      writeFileSync(outputFile, json, 'utf-8');
    } else {
      console.log(json);
    }
  } else if (direction === 'yaml') {
    // JSON → YAML
    const data = JSON.parse(readFileSync(inputFile, 'utf-8'));
    const yaml = safeDump(data);

    if (outputFile) {
      writeFileSync(outputFile, yaml, 'utf-8');
    } else {
      console.log(yaml);
    }
  } else {
    console.error('Direction must be "yaml" or "json"');
    process.exit(1);
  }
} catch (error) {
  console.error('Conversion error:', error.message);
  process.exit(1);
}
```

**Usage:**

```bash
# JSON → YAML
./yaml-json-convert.ts yaml config.json config.yaml

# YAML → JSON
./yaml-json-convert.ts json config.yaml config.json

# Output to stdout
./yaml-json-convert.ts yaml config.json
```

## Error Handling

### YAMLError Class

```typescript
class YAMLError extends Error {
  line: number;      // Line number where error occurred
  column: number;    // Column number where error occurred
  message: string;   // Error description
}
```

### Handling Parse Errors

```typescript
import { safeLoad, YAMLError } from 'fastyaml-rs';

try {
  const data = safeLoad('invalid: yaml: syntax:');
} catch (error) {
  if (error instanceof YAMLError) {
    console.error(`YAML Syntax Error at line ${error.line}, column ${error.column}`);
    console.error(`Message: ${error.message}`);
  } else {
    console.error('Unexpected error:', error);
  }
}
```

### Validation Helper

```typescript
import { safeLoad, YAMLError } from 'fastyaml-rs';
import { readFileSync } from 'fs';

function loadYAMLFile(path: string): any {
  try {
    const content = readFileSync(path, 'utf-8');
    return safeLoad(content);
  } catch (error) {
    if (error instanceof YAMLError) {
      throw new Error(`Invalid YAML in ${path} at line ${error.line}: ${error.message}`);
    }
    throw error;
  }
}

// Usage
try {
  const config = loadYAMLFile('config.yaml');
  console.log('Configuration loaded:', config);
} catch (error) {
  console.error('Failed to load configuration:', error.message);
  process.exit(1);
}
```

## Advanced Usage

### TypeScript Type Safety

```typescript
import { safeLoad } from 'fastyaml-rs';

interface DatabaseConfig {
  host: string;
  port: number;
  database: string;
  ssl?: boolean;
}

function loadDatabaseConfig(yamlStr: string): DatabaseConfig {
  const config = safeLoad(yamlStr) as DatabaseConfig;

  // Runtime validation
  if (!config.host || typeof config.host !== 'string') {
    throw new Error('Invalid host configuration');
  }
  if (!config.port || typeof config.port !== 'number') {
    throw new Error('Invalid port configuration');
  }

  return config;
}

// Usage
const yamlStr = `
host: localhost
port: 5432
database: myapp
ssl: true
`;

const config = loadDatabaseConfig(yamlStr);
console.log(`Connecting to ${config.host}:${config.port}`);
```

### Configuration Management

```typescript
import { safeLoad, safeDump } from 'fastyaml-rs';
import { readFileSync, writeFileSync } from 'fs';

class ConfigManager {
  private config: any;
  private path: string;

  constructor(path: string) {
    this.path = path;
    this.load();
  }

  load(): void {
    const content = readFileSync(this.path, 'utf-8');
    this.config = safeLoad(content);
  }

  get(key: string): any {
    return this.config[key];
  }

  set(key: string, value: any): void {
    this.config[key] = value;
  }

  save(): void {
    const yaml = safeDump(this.config, { indent: 2 });
    writeFileSync(this.path, yaml, 'utf-8');
  }
}

// Usage
const config = new ConfigManager('config.yaml');
console.log('Database host:', config.get('database').host);

config.set('database', { host: 'newhost', port: 5433 });
config.save();
```

### Stream Processing

```typescript
import { safeLoadAll } from 'fastyaml-rs';
import { createReadStream } from 'fs';
import { createInterface } from 'readline';

async function processLargeYAML(path: string): Promise<void> {
  const fileStream = createReadStream(path);
  const rl = createInterface({
    input: fileStream,
    crlfDelay: Infinity
  });

  let buffer = '';
  let docCount = 0;

  for await (const line of rl) {
    buffer += line + '\n';

    // Process when document separator found
    if (line.trim() === '---' && buffer.length > 4) {
      const docs = safeLoadAll(buffer);
      for (const doc of docs) {
        await processDocument(doc);
        docCount++;
      }
      buffer = '---\n';
    }
  }

  // Process remaining buffer
  if (buffer.trim().length > 0) {
    const docs = safeLoadAll(buffer);
    for (const doc of docs) {
      await processDocument(doc);
      docCount++;
    }
  }

  console.log(`Processed ${docCount} documents`);
}

async function processDocument(doc: any): Promise<void> {
  // Process individual document
  console.log('Processing:', doc);
}
```

### Express.js Middleware

```typescript
import express from 'express';
import { safeLoad, safeDump } from 'fastyaml-rs';

const app = express();

// YAML body parser
app.use(express.text({ type: 'application/yaml' }));

app.post('/api/config', (req, res) => {
  try {
    // Parse YAML body
    const config = safeLoad(req.body);

    // Validate config
    if (!config.name || !config.version) {
      return res.status(400).json({
        error: 'Missing required fields: name, version'
      });
    }

    // Process config
    console.log('Received configuration:', config);

    // Return as YAML
    res.type('application/yaml');
    res.send(safeDump(config));
  } catch (error) {
    res.status(400).json({
      error: 'Invalid YAML',
      message: error.message
    });
  }
});

app.listen(3000, () => {
  console.log('Server listening on port 3000');
});
```

### Webpack/Vite Plugin

```typescript
// webpack.config.js
import { safeLoad } from 'fastyaml-rs';

export default {
  module: {
    rules: [
      {
        test: /\.yaml$/,
        type: 'json',
        parser: {
          parse: safeLoad
        }
      }
    ]
  }
};

// Usage in application
import config from './config.yaml';
console.log(config.database.host);
```

### Jest Testing

```typescript
// config.test.ts
import { safeLoad, safeDump } from 'fastyaml-rs';

describe('Configuration', () => {
  it('should load valid YAML', () => {
    const yaml = 'name: test\nversion: 1.0';
    const config = safeLoad(yaml);

    expect(config.name).toBe('test');
    expect(config.version).toBe('1.0');
  });

  it('should throw on invalid YAML', () => {
    const invalidYaml = 'invalid: yaml: syntax:';

    expect(() => {
      safeLoad(invalidYaml);
    }).toThrow();
  });

  it('should round-trip correctly', () => {
    const original = {
      name: 'test',
      features: ['a', 'b', 'c']
    };

    const yaml = safeDump(original);
    const parsed = safeLoad(yaml);

    expect(parsed).toEqual(original);
  });
});
```

## Migration from js-yaml

### Drop-in Replacement

```typescript
// Before (js-yaml)
import yaml from 'js-yaml';
const data = yaml.load(yamlStr);
const yamlStr = yaml.dump(data);

// After (fast-yaml)
import { safeLoad as load, safeDump as dump } from 'fastyaml-rs';
const data = load(yamlStr);
const yamlStr = dump(data);
```

### Handling YAML 1.2.2 Differences

```typescript
// js-yaml (YAML 1.1) behavior
import yaml from 'js-yaml';
const data = yaml.load('enabled: yes');
console.log(data); // { enabled: true }

// fast-yaml (YAML 1.2.2) behavior
import { safeLoad } from 'fastyaml-rs';
const data = safeLoad('enabled: yes');
console.log(data); // { enabled: 'yes' }

// Migration: use explicit booleans
const data = safeLoad('enabled: true');
console.log(data); // { enabled: true }
```

See [yaml-spec.md](yaml-spec.md) for complete migration guide.

## Performance Benchmarks

Compared to js-yaml:

| Operation | Small Files (<10KB) | Medium Files (100KB) | Large Files (>1MB) |
|-----------|---------------------|----------------------|--------------------|
| Parse | 1.3x faster | 1.4x faster | 1.5x faster |
| Dump | 1.2x faster | 1.3x faster | 1.4x faster |

**Note:** Benchmarks on Node.js 20.x, comparing against js-yaml 4.x.

## Thread Safety

fast-yaml uses native Rust bindings and is thread-safe:

```typescript
import { Worker } from 'worker_threads';
import { safeLoad } from 'fastyaml-rs';

// Safe to use across workers
const worker = new Worker('./worker.js');
worker.postMessage({ yaml: yamlString });

// worker.js
import { safeLoad } from 'fastyaml-rs';
import { parentPort } from 'worker_threads';

parentPort.on('message', ({ yaml }) => {
  const data = safeLoad(yaml);
  parentPort.postMessage({ data });
});
```

## API Reference Summary

| Function | Parameters | Returns | Description |
|----------|-----------|---------|-------------|
| `safeLoad` | `string` | `any` | Parse YAML string to object |
| `safeLoadAll` | `string` | `any[]` | Parse multi-document YAML |
| `safeDump` | `any, DumpOptions?` | `string` | Serialize object to YAML |
| `safeDumpAll` | `any[], DumpOptions?` | `string` | Serialize multiple objects |

## Browser Support

fast-yaml can be used in browsers via bundlers:

```typescript
// Webpack/Vite/Rollup will bundle the WASM module
import { safeLoad, safeDump } from 'fastyaml-rs';

const data = safeLoad(yamlString);
console.log(data);
```

**Note:** Ensure your bundler supports WASM modules. Most modern bundlers (Webpack 5+, Vite 2+) support this out of the box.
