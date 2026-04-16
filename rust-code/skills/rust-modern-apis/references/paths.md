# Path and PathBuf APIs

## `PathBuf::add_extension` / `Path::with_added_extension` — 1.91

**This is the most important addition in 1.91 for file-handling code.** It fixes a long-standing footgun with `with_extension`.

### The problem these APIs solve

`with_extension` **replaces** the final extension. For `foo.tar.gz` → `with_extension("bak")` yields `foo.tar.bak`, dropping `.gz`. For paths with only one "extension" this rarely matters, but for compound extensions and when you want to *add* a suffix (not replace), it breaks.

Many codebases have workarounds like `format!("{}.tmp", path.display())` or manually composing via `file_stem`. These all become unnecessary.

### Usage

```rust
// add_extension: mutates in place
let mut p = PathBuf::from("data.json");
p.add_extension("tmp");
assert_eq!(p, PathBuf::from("data.json.tmp"));

// with_added_extension: returns a new PathBuf
let p = Path::new("data.json").with_added_extension("tmp");
assert_eq!(p, PathBuf::from("data.json.tmp"));

// Compare to with_extension, which REPLACES:
let wrong = Path::new("data.json").with_extension("tmp");
assert_eq!(wrong, PathBuf::from("data.tmp")); // lost .json!
```

### Common sites to replace

- **Atomic writes** via tmp file: `path.with_extension("tmp")` is often wrong for `.jsonl`, `.tar.gz`, etc. Use `with_added_extension("tmp")`.
- **Sidecar files**: for `audit.log` + `.meta.json`, `with_extension("meta.json")` works by accident (no other dots), but `with_added_extension("meta.json")` is explicit and future-proof.
- **Backup files**: `config.toml.bak`, `db.sqlite.backup`, etc.

## `Path::file_prefix` — 1.91

**Like `file_stem` but stops at the first dot, not the last.**

```rust
let p = Path::new("archive.tar.gz");

assert_eq!(p.file_stem(),   Some(OsStr::new("archive.tar"))); // last dot
assert_eq!(p.file_prefix(), Some(OsStr::new("archive")));     // first dot
```

Use when you want the "base name" ignoring all extensions. Rare in code — most codebases only use `file_stem`, which is usually fine.

## `PartialEq` between `Path`/`PathBuf` and `&str`/`String` — 1.91

**Removes the need for `to_string_lossy()` in comparisons.**

```rust
let p = Path::new("/etc/hostname");

// Before (allocates)
if p.to_string_lossy() == "/etc/hostname" { /* ... */ }

// After (1.91+) — direct comparison, no allocation
if p == "/etc/hostname" { /* ... */ }
if p == Path::new("/etc/hostname") { /* ... */ }
```

Available impls: `Path == str`, `Path == String`, `PathBuf == str`, `PathBuf == String`, plus the symmetric reverse directions.

**Caveat:** this is a byte-level comparison that respects platform encoding. On Windows, non-UTF-8 paths will never equal any `str` (because `&str` is always UTF-8). Use `OsStr`/`OsString` for those.

## Summary: use these three together

The 1.91 path APIs are designed to be used together. Before:

```rust
let meta_path = if let (Some(parent), Some(stem)) = (path.parent(), path.file_stem()) {
    parent.join(format!("{}.meta.json", stem.to_string_lossy()))
} else {
    path.with_extension("meta.json")
};
if meta_path.to_string_lossy().ends_with("backup.meta.json") { /* ... */ }
```

After:

```rust
let meta_path = path.with_added_extension("meta.json");
if meta_path == "backup.meta.json" { /* ... */ }
```

Three lines replaced one, two allocations removed, and the edge case for paths without a file name is correctly handled (`with_added_extension` returns the path unchanged if there's no file name).
