# Technical Writing Style Guide

## Voice & Tone

### Use Second Person + Imperative Mood

```
✅ "Run the following command to start the server."
✅ "You can configure the timeout in `config.toml`."
❌ "The command should be run to start the server."
❌ "One can configure the timeout..."
❌ "We will now run the command..."
```

Exception: Architecture docs may use "we" when describing team decisions: "We chose event sourcing because..."

### Be Direct

```
✅ "This function panics if the input is empty."
❌ "It should be noted that this function may panic if the input is empty."
❌ "Please be aware that this function panics if the input is empty."
```

Remove filler words: "basically", "simply", "just", "actually", "in order to", "it should be noted that".

### Present Tense

```
✅ "The server starts on port 8080."
❌ "The server will start on port 8080."
```

Exception: Future tense for roadmap items or planned features.

## Structure

### Chapter Structure

Every chapter follows this skeleton:

1. **H1 Title** — matches SUMMARY.md entry exactly
2. **Opening paragraph** — what the reader will learn and why it matters (2-3 sentences)
3. **Prerequisites** (if any) — what the reader needs before starting
4. **Body** — the main content, organized with H2/H3
5. **Summary/Next steps** — what was covered, what to read next

### Heading Hierarchy

- **H1** (`#`): Chapter title. Exactly one per file.
- **H2** (`##`): Major sections within a chapter.
- **H3** (`###`): Subsections. Use sparingly.
- **H4** (`####`): Avoid. If you need H4, restructure into separate chapters.

Never skip heading levels (H1 → H3 without H2).

### Paragraph Rules

- One idea per paragraph.
- Max 5 sentences per paragraph.
- First sentence should summarize the paragraph's point.
- If a paragraph exceeds 5 sentences, split it or convert to a list.

### Lists

Use numbered lists only for sequential steps. Use bullet lists for unordered items.

```markdown
## Steps

1. Install the dependency.
2. Add the configuration entry.
3. Restart the service.

## Supported Formats

- JSON
- TOML
- YAML
```

Keep list items parallel in grammar:

```
✅ Items start with the same part of speech:
- Configure the database connection
- Set the logging level
- Enable authentication

❌ Mixed grammar:
- Database configuration
- Set the logging level
- Authentication should be enabled
```

## Code Examples

### Every Example Must Be Complete

```
✅ Shows all necessary imports, setup, and a full runnable snippet.
❌ Shows a fragment that requires the reader to figure out context.
```

### Annotate Language

Always specify the language in fenced code blocks:

````markdown
```rust
fn main() {
    println!("Hello");
}
```

```toml
[dependencies]
serde = { version = "1", features = ["derive"] }
```

```bash
cargo run --release
```
````

### Use Hidden Lines for Boilerplate (Rust)

````markdown
```rust
# use anyhow::Result;
# fn main() -> Result<()> {
let config = Config::from_file("config.toml")?;
let server = Server::new(config);
server.run()?;
# Ok(())
# }
```
````

### Show Output When Helpful

```markdown
```bash
$ cargo run -- --help
Usage: myapp [OPTIONS] <COMMAND>

Commands:
  serve    Start the server
  migrate  Run database migrations
  help     Print help
```
```

### Error Examples

Show common errors and how to fix them:

```markdown
If you see this error:

```
Error: connection refused (os error 111)
```

Check that the database is running:

```bash
systemctl status postgresql
```
```

## Terminology

### Consistency Rules

- Pick one term and stick with it. Don't alternate between "config file" and "configuration file".
- Define jargon on first use: "The *borrow checker* — Rust's compile-time mechanism for memory safety — prevents..."
- Use the Rust ecosystem's standard terms: "crate" (not "package" or "library" except when specifically meaning Cargo package vs lib crate), "trait" (not "interface"), "struct" (not "class").

### Capitalization

- Tool names: mdBook (not MdBook, mdbook except in CLI context), Cargo, Rust, Tokio
- Concepts: lowercase unless starting a sentence — "the borrow checker", "pattern matching"
- CLI commands: always monospace — `mdbook build`, `cargo test`

### Punctuation

- Use the Oxford comma: "JSON, TOML, and YAML"
- Em dashes (`—`) for parenthetical remarks, not hyphens or en dashes
- No period after single-sentence list items; period after multi-sentence items

## Rust-Specific Documentation Conventions

### Link to `docs.rs`

When referencing types or functions from dependencies, link to docs.rs:

```markdown
[`tokio::spawn`](https://docs.rs/tokio/latest/tokio/fn.spawn.html)
```

### Refer to `rustdoc` Output

For the project's own types, either generate and host rustdoc alongside mdBook, or document inline:

```markdown
The [`Config`] struct holds all runtime settings. See the [API reference](../api-reference/config.md) for field-level documentation.
```

### Error Handling Patterns

Document how your project handles errors:

```markdown
## Error Handling

This library uses [`thiserror`](https://docs.rs/thiserror) for error types.
All public functions return `Result<T, ProjectError>`.

| Error Variant | When It Occurs | Suggested Action |
|--------------|----------------|------------------|
| `ConfigError` | Invalid configuration file | Check TOML syntax |
| `IoError` | File system operations fail | Verify permissions |
| `NetworkError` | Connection failures | Check network/retry |
```

## Cross-Referencing

### Internal Links

Use relative paths:

```markdown
See [Installation](../getting-started/installation.md) for setup instructions.
```

Link to specific sections with anchors:

```markdown
See [TLS Configuration](../operations/deployment.md#tls-configuration).
```

mdBook auto-generates anchors from headings: "TLS Configuration" → `#tls-configuration`.

### External Links

- Always link to stable/versioned docs, not `latest` when precision matters.
- Prefer official sources: docs.rs, Rust Reference, TRPL (The Rust Programming Language).
- Check links periodically — add to CI if possible.

## Accessibility

- Use descriptive link text, not "click here"
- Add alt text for images: `![Architecture diagram showing request flow](./images/arch.png)`
- Use semantic heading hierarchy for screen readers
- Don't rely on color alone to convey meaning
- Keep tables simple; complex data should be in structured text

## Localization Considerations

If the docs may be translated:

- Avoid idioms and slang
- Keep sentences simple (SVO structure)
- Don't embed text in images
- Use ISO date format (YYYY-MM-DD) or spell out months
