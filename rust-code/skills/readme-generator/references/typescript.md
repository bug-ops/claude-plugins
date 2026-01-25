# TypeScript/JavaScript README Template

> [!IMPORTANT]
> Always show ALL major package managers (npm/yarn/pnpm/bun). Users have strong preferences.

## Structure

```markdown
# package-name

[![npm](https://img.shields.io/npm/v/{package})](https://www.npmjs.com/package/{package})
[![Bundle Size](https://img.shields.io/bundlephobia/minzip/{package})](https://bundlephobia.com/package/{package})
[![TypeScript](https://img.shields.io/badge/TypeScript-Ready-blue)](https://www.typescriptlang.org/)
[![CI](https://img.shields.io/github/actions/workflow/status/{owner}/{repo}/ci.yml)](https://github.com/{owner}/{repo}/actions)
[![License](https://img.shields.io/npm/l/{package})](LICENSE)

One-line description from package.json.

## Installation

\`\`\`bash
# npm
npm install {package}

# yarn
yarn add {package}

# pnpm
pnpm add {package}

# bun
bun add {package}
\`\`\`

> [!NOTE]
> This package includes TypeScript definitions. No need for separate `@types` package.

## Quick Start

\`\`\`typescript
import { Thing } from '{package}';

const thing = new Thing();
console.log(thing.doSomething());
\`\`\`

## Usage

### Basic Example

\`\`\`typescript
import { createThing, type ThingOptions } from '{package}';

const options: ThingOptions = {
  option1: 'value',
  option2: true,
};

const thing = createThing(options);
\`\`\`

### With React

\`\`\`tsx
import { useThing } from '{package}/react';

function MyComponent() {
  const { data, loading } = useThing();
  
  if (loading) return <div>Loading...</div>;
  return <div>{data}</div>;
}
\`\`\`

> [!TIP]
> Use framework-specific subpaths like `/react`, `/vue` for optimized integrations.

## API

### `createThing(options)`

Creates a new Thing instance.

**Parameters:**

| Name | Type | Required | Description |
|------|------|----------|-------------|
| `option1` | `string` | Yes | Description |
| `option2` | `boolean` | No | Description (default: `false`) |

**Returns:** `Thing`

### `Thing.doSomething()`

Does something useful.

**Returns:** `Promise<Result>`

## TypeScript

This package includes TypeScript definitions. Import types directly:

\`\`\`typescript
import type { Thing, ThingOptions, Result } from '{package}';
\`\`\`

## Browser Support

| Browser | Version |
|---------|---------|
| Chrome | 80+ |
| Firefox | 75+ |
| Safari | 13+ |
| Edge | 80+ |

## License

[{license}](LICENSE)
```

## TypeScript-Specific Requirements

### Package Manager Tabs

Always show all major package managers:

```markdown
\`\`\`bash
# npm
npm install {package}

# yarn  
yarn add {package}

# pnpm
pnpm add {package}

# bun
bun add {package}
\`\`\`
```

Or use HTML details for cleaner look:

```html
<details>
<summary>npm</summary>

```bash
npm install {package}
```

</details>

<details>
<summary>yarn</summary>

```bash
yarn add {package}
```

</details>
```

### TypeScript Support

Always indicate TypeScript support:

1. Badge: `[![TypeScript](https://img.shields.io/badge/TypeScript-Ready-blue)]`
2. Show typed imports
3. Document exported types

```typescript
// Show type inference
import { z } from 'zod';

const User = z.object({
  name: z.string(),
  age: z.number(),
});

type User = z.infer<typeof User>;
//   ^? { name: string; age: number }
```

### Bundle Size

> [!WARNING]
> Bundle size badge is critical for frontend packages. Missing it signals the author doesn't care about performance.

Important for frontend packages:

```markdown
[![Bundle Size](https://img.shields.io/bundlephobia/minzip/{package})](https://bundlephobia.com/package/{package})
```

Document tree-shaking support:

```markdown
## Bundle Size

This package is tree-shakeable. Import only what you need:

\`\`\`typescript
// ✅ Good - only imports used functions
import { specificFunction } from '{package}';

// ❌ Avoid - imports entire package  
import * as pkg from '{package}';
\`\`\`
```

### ESM/CJS Support

Document module formats:

```markdown
## Module Formats

This package ships both ESM and CommonJS:

\`\`\`javascript
// ESM
import { thing } from '{package}';

// CommonJS
const { thing } = require('{package}');
\`\`\`
```

### Framework Integration

If package has framework-specific exports:

```markdown
## Framework Support

| Framework | Import |
|-----------|--------|
| React | `{package}/react` |
| Vue | `{package}/vue` |
| Svelte | `{package}/svelte` |
| Vanilla | `{package}` |
```

### Node.js Version

Document minimum Node.js version:

```markdown
## Requirements

- Node.js >= 18.0.0
```

Or with badge:

```markdown
[![Node](https://img.shields.io/node/v/{package})](https://nodejs.org)
```

### Async/Await Examples

Modern packages should show async patterns:

```typescript
// Async/await
const result = await thing.doAsync();

// Promise chain (alternative)
thing.doAsync().then(result => {
  console.log(result);
});
```

### Error Handling

Show proper error handling:

```typescript
import { Thing, ThingError } from '{package}';

try {
  const result = await thing.doSomething();
} catch (error) {
  if (error instanceof ThingError) {
    console.error('Thing failed:', error.message);
  }
  throw error;
}
```

## Badge Priority for TypeScript

1. npm version (required)
2. Bundle size (required for frontend)
3. TypeScript badge (recommended)
4. CI status (recommended)
5. License (required)
6. Downloads (optional)
7. Code coverage (optional)

## CDN Usage

For browser packages, show CDN usage:

```markdown
## CDN

\`\`\`html
<!-- unpkg -->
<script src="https://unpkg.com/{package}"></script>

<!-- jsDelivr -->
<script src="https://cdn.jsdelivr.net/npm/{package}"></script>

<!-- ESM -->
<script type="module">
  import { thing } from 'https://esm.sh/{package}';
</script>
\`\`\`
```

## Monorepo Packages

For workspace packages:

```markdown
## Related Packages

| Package | Description |
|---------|-------------|
| `@scope/core` | Core functionality |
| `@scope/react` | React bindings |
| `@scope/cli` | CLI tool |
```

## Dev Dependencies

If package is a dev tool:

```markdown
## Installation

\`\`\`bash
npm install --save-dev {package}
\`\`\`
```

Add to scripts:

```markdown
Add to `package.json`:

\`\`\`json
{
  "scripts": {
    "lint": "{package} .",
    "lint:fix": "{package} . --fix"
  }
}
\`\`\`
```
