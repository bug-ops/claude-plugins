# Exemplary README Analysis

> [!TIP]
> Study these examples before writing. Each demonstrates battle-tested patterns from projects with 10k+ stars.

Patterns extracted from top-rated READMEs in awesome-readme collection.

## Top Rust Examples

### tokio-rs/tokio

**Why it's great:**

- Clear one-liner: "A runtime for writing reliable asynchronous applications"
- Prominent "getting started" link
- Feature list with concise descriptions
- MSRV policy clearly stated
- Modular crate breakdown

**Pattern to copy:**

```markdown
## Getting Started

[`tokio`]: https://docs.rs/tokio

The easiest way to get started is to enable all features:

\`\`\`toml
[dependencies]
tokio = { version = "1", features = ["full"] }
\`\`\`

See [documentation][`tokio`] for more details.
```

### BurntSushi/ripgrep

**Why it's great:**

- Terminal screenshot showing actual usage
- Comprehensive installation (10+ methods)
- Feature comparison table vs grep/ag
- Performance benchmarks
- Shell completion instructions

**Pattern to copy:**

```markdown
## Installation

Binaries for ripgrep are available for Windows, macOS and Linux.

If you're a **Rust programmer**, ripgrep can be installed with `cargo`:

\`\`\`
$ cargo install ripgrep
\`\`\`

Alternatively, one can use various package managers...
```

### serde-rs/serde

**Why it's great:**

- "Serde is a framework for..." immediately explains purpose
- Live playground link
- Multiple derive examples
- Clear feature flag documentation
- Links to ecosystem crates

**Pattern to copy:**

```markdown
## Serde in action

\`\`\`rust
use serde::{Deserialize, Serialize};

#[derive(Serialize, Deserialize, Debug)]
struct Point {
    x: i32,
    y: i32,
}

fn main() {
    let point = Point { x: 1, y: 2 };
    let serialized = serde_json::to_string(&point).unwrap();
    println!("serialized = {}", serialized);
}
\`\`\`
```

## Top TypeScript Examples

### sindresorhus/got

**Why it's great:**

- Comparison table with alternatives (axios, node-fetch, etc.)
- Request example as first code block
- Progressive complexity in examples
- TypeScript example with generics

**Pattern to copy:**

```markdown
## Comparison

| | `got` | `node-fetch` | `axios` |
|---|---|---|---|
| HTTP/2 support | ✅ | ❌ | ❌ |
| Pagination | ✅ | ❌ | ❌ |
| Retries | ✅ | ❌ | ❌ |
```

### colinhacks/zod

**Why it's great:**

- Type inference demonstration
- Copy-pasteable examples for every feature
- "Why Zod?" section
- Comparison with alternatives
- Sponsorship section

**Pattern to copy:**

```markdown
## Basic usage

\`\`\`ts
import { z } from "zod";

const User = z.object({
  username: z.string(),
});

User.parse({ username: "Ludwig" });

// extract the inferred type
type User = z.infer<typeof User>;
// { username: string }
\`\`\`
```

## Top Python Examples

### psf/httpx

**Why it's great:**

- "HTTPX is a fully featured HTTP client" - clear positioning
- Sync and async examples side by side
- Installation with extras
- Feature matrix
- "Why HTTPX?" section

**Pattern to copy:**

```markdown
## Quickstart

\`\`\`python
>>> import httpx
>>> r = httpx.get('https://www.example.org/')
>>> r.status_code
200
\`\`\`

Or, using async:

\`\`\`python
>>> async with httpx.AsyncClient() as client:
...     r = await client.get('https://www.example.org/')
>>> r.status_code
200
\`\`\`
```

### tiangolo/fastapi

**Why it's great:**

- Performance claims with benchmarks
- Interactive docs demo (swagger)
- Step-by-step tutorial links
- Testimonials from companies
- Comparison with alternatives

**Pattern to copy:**

```markdown
## Performance

FastAPI is built on Starlette and Pydantic. Independent TechEmpower benchmarks show...

## Features

- **Fast**: Very high performance, on par with **NodeJS** and **Go**
- **Fast to code**: Increase speed to develop features by 200-300%
- **Intuitive**: Great editor support. Completion everywhere
```

## Common Patterns

### The Hook Pattern

First 3 lines grab attention:

```markdown
# project-name

One-line description that explains what problem this solves.

![Demo GIF or screenshot](assets/demo.gif)
```

### The Progressive Disclosure Pattern

Structure for complex projects:

```markdown
## Quick Start
(5 lines max - get something working)

## Installation  
(All methods)

## Usage
(Common cases)

## Advanced
(Deep dives, link to docs)
```

### The Comparison Pattern

Position against alternatives:

```markdown
## Why project-name?

| Feature | project-name | alternative1 | alternative2 |
|---------|--------------|--------------|--------------|
| Speed | ✅ Fast | ⚠️ Slow | ✅ Fast |
| Types | ✅ Full | ❌ None | ⚠️ Partial |
```

### The Example-First Pattern

Show code before explanation:

```markdown
## Usage

\`\`\`rust
// This just works
let result = thing.do_it();
\`\`\`

The `do_it()` method handles X, Y, and Z automatically.
```

## Anti-Patterns to Avoid

> [!WARNING]
> These are the most common README failures. Avoid all of them.

### Wall of Text

❌ Long paragraphs without code
✅ Short paragraphs + code examples

### Badge Overload

❌ 15 badges in rainbow colors
✅ 4-6 relevant badges

### No Installation

❌ Assumes user knows how to install
✅ Copy-pasteable install command first

### Generic Description

❌ "A library for doing things"
✅ "Fast JSON parser with streaming support"

### Outdated Examples

❌ Code that doesn't compile
✅ Examples tested in CI

### Missing License

❌ No license information
✅ Clear license badge + link

## Structure Reference

Ideal README length by project complexity:

| Project Type | Ideal Length | TOC? |
|-------------|--------------|------|
| Simple library | 200-400 words | No |
| Complex library | 500-1000 words | Optional |
| Framework | 1000-2000 words | Yes |
| CLI tool | 500-1500 words | Yes |
| Application | 1000-3000 words | Yes |
