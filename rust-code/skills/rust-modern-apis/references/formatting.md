# Formatting APIs

## `std::fmt::from_fn(|f: &mut Formatter| -> fmt::Result) -> impl Display + Debug` — 1.93

**Replaces:** one-off `impl Display` types created for a single call site.

### The problem

Sometimes you want a `Display` or `Debug` impl for a local formatting need — without defining a newtype struct just to carry an impl:

```rust
// Before — required a type
struct HexDump<'a>(&'a [u8]);
impl fmt::Display for HexDump<'_> {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        for b in self.0 {
            write!(f, "{:02x} ", b)?;
        }
        Ok(())
    }
}
println!("{}", HexDump(&bytes));
```

### After

```rust
// After (1.93+) — inline, no type needed
let dump = std::fmt::from_fn(|f| {
    for b in &bytes {
        write!(f, "{:02x} ", b)?;
    }
    Ok(())
});
println!("{dump}");
```

The returned value implements both `Display` and `Debug`. The closure is called once per format invocation (once per `{}` in the format string) — which matters if the closure is expensive or captures something with side effects.

### When to use

- **One-off inline formatters** where a full impl is overkill.
- **Building formatters from closures** that capture local state. Escaping closures, thread-local state, etc.
- **Conditionally-built formatters** — `let prefix = if verbose { ... } else { fmt::from_fn(|_| Ok(())) };`

### When NOT to use

- **Reusable formatters on public types.** If other modules will format your data, a real `impl Display` documents the contract and is discoverable.
- **Performance-critical inner loops.** The closure is a trait object internally; a direct `write!` into the formatter is simpler.

## `Debug` impl for raw pointers now prints metadata — 1.87

**Compatibility note.** `Debug` for `*const T` / `*mut T` now prints pointer metadata (length for slice pointers, vtable for trait object pointers) in addition to the address:

```rust
let s: &[u32] = &[1, 2, 3];
let p: *const [u32] = s;
println!("{p:?}");
// Before: 0x7fffd...
// After:  Pointer { addr: 0x7fffd..., metadata: 3 }
```

If your test snapshots or log parsers expected the old format, they'll need updating. Otherwise a usability improvement.

## `EncodeWide` now implements `Debug` — 1.91

`std::os::windows::ffi::EncodeWide` (the iterator from `OsStr::encode_wide`) now derives `Debug`. Lets you debug-print Windows OS strings without manual iteration.

## `str::from_utf8` / `from_utf8_mut` / `from_utf8_unchecked` / `from_utf8_unchecked_mut` as inherent methods — 1.87

Now accessible as `str::from_utf8(bytes)` rather than requiring the free `std::str::from_utf8` path:

```rust
// Before
let s = std::str::from_utf8(bytes)?;

// After (1.87+) — inherent method, slightly more discoverable
let s = str::from_utf8(bytes)?;
```

Purely cosmetic.

## Width / precision format options now limited to 16 bits — 1.87 (compatibility)

**Compatibility change.** `{:width$}` and `{:.precision$}` format specifiers now clamp width/precision to `u16::MAX` (65535). Wider values silently saturate.

Previously, pathologically large widths (e.g., `{:9999999999$}`) would allocate huge buffers. Now capped. If you were intentionally using huge widths (unlikely), this is a behavior change.

## Macros now support `const { }` expressions — 1.87

`assert_eq!`, `vec!`, `format!`, etc. now accept const blocks in their args:

```rust
assert_eq!(value, const { BASE + OFFSET });
```

Small change; marginally useful for keeping constant expressions evaluated at compile time without intermediate `const` items.

## `os_str::Display` / `OsString::display` / `OsStr::display` — 1.87

Unified display for `OsStr` / `OsString` via a `.display()` method — similar to `Path::display`:

```rust
// Before
println!("{}", my_osstr.to_string_lossy());  // allocates

// After (1.87+)
println!("{}", my_osstr.display());  // lazy, no allocation
```

Like `Path::display`, it replaces invalid bytes with U+FFFD rather than panicking on non-UTF-8.
