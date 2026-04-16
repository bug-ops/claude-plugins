# Collection APIs

## `Vec::extract_if` / `LinkedList::extract_if` — 1.87

## `HashMap::extract_if` / `HashSet::extract_if` — 1.88

## `BTreeMap::extract_if` / `BTreeSet::extract_if` — 1.91

**The correct tool when you need to remove items from a collection AND do something with them.**

### When `retain` is wrong

`retain(|x| predicate(x))` removes items that don't match the predicate — but discards them. If you want to count, log, or further process the removed items, `retain` forces you to either:

1. Compute removed elsewhere (e.g., `len_before - len_after` for a count), or
2. Smuggle side effects into the closure (hurts readability, fragile under concurrent modification, breaks if `retain` iterates out of order).

`extract_if` returns an iterator of the removed elements. Clean separation of "what to remove" and "what to do with removed".

### Signatures differ by collection

- **`Vec::extract_if(range, |&mut v| -> bool) -> ExtractIf<...>`** — filters within a range, returns removed items in iteration order.
- **`HashMap::extract_if(|&k, &mut v| -> bool) -> ExtractIf<...>`** — returns `(K, V)` tuples.
- **`HashSet::extract_if(|&v| -> bool) -> ExtractIf<...>`** — returns owned `V`.
- **`BTreeMap::extract_if(range, |&k, &mut v| -> bool) -> ExtractIf<...>`** — filters within a key range.
- **`BTreeSet::extract_if(range, |&v| -> bool) -> ExtractIf<...>`** — filters within a range.

### Lazy iterator behavior

`extract_if` returns a lazy iterator. **Items are only removed as you pull them.** If you drop the iterator without consuming it, the remaining items stay in the collection. This is a common pitfall — `.collect::<Vec<_>>()` or a full `for` loop is usually what you want:

```rust
// Removes nothing — iterator is dropped without being consumed
let _ = vec.extract_if(.., |x| is_expired(x));

// Correct: consume the iterator
let expired: Vec<_> = vec.extract_if(.., |x| is_expired(x)).collect();
for item in &expired {
    log::debug!("expired: {item:?}");
}
```

### Migration example

```rust
// Before — logging inside retain closure
fn sweep_expired(&mut self) {
    let before = self.grants.len();
    self.grants.retain(|g| {
        let expired = g.is_expired();
        if expired {
            tracing::debug!(kind = %g.kind, "expired and revoked");
        }
        !expired
    });
    let removed = before - self.grants.len();
    if removed > 0 {
        tracing::debug!(removed, "swept expired grants");
    }
}

// After — clean separation
fn sweep_expired(&mut self) {
    let expired: Vec<_> = self.grants.extract_if(.., |g| g.is_expired()).collect();
    for g in &expired {
        tracing::debug!(kind = %g.kind, "expired and revoked");
    }
    if !expired.is_empty() {
        tracing::debug!(removed = expired.len(), "swept expired grants");
    }
}
```

### When NOT to use extract_if

- **Rate-limiter eviction** where the evicted entries are genuinely uninteresting. `retain` is shorter and clearer.
- **When order matters for Hash collections**. `HashMap::extract_if` iterates in the map's internal (unspecified) order — don't rely on it.
- **When under a lock where you need fast release.** Collecting into `Vec` extends the lock hold time. Consider moving the lock scope to be minimal: lock, collect removed, release, then log.

## `VecDeque::pop_front_if` / `pop_back_if` — 1.93

**Conditional pop — only removes if predicate holds.**

```rust
// Before
if queue.front().is_some_and(|front| should_drop(front)) {
    queue.pop_front();
}

// After (1.93+)
queue.pop_front_if(|front| should_drop(front));
```

Parallels `Vec::pop_if` (1.86) which was already stable. Useful in queues where you conditionally drain — e.g., "drop the oldest if it's expired."

## `String::into_raw_parts` / `Vec::into_raw_parts` — 1.93

**Decompose into `(ptr, len, cap)` for FFI or custom allocator integration.**

```rust
let v: Vec<u8> = vec![1, 2, 3];
let (ptr, len, cap) = v.into_raw_parts();
// Later — rebuild the Vec (unsafe — must match original allocator/layout)
let v = unsafe { Vec::from_raw_parts(ptr, len, cap) };
```

Only useful if you're building FFI layers or similar low-level code. For `unsafe_code = "deny"` projects, skip.

## `btree_map::Entry::insert_entry` / `VacantEntry::insert_entry` — 1.92

Returns an `OccupiedEntry` after inserting, letting you continue manipulating the entry without a second lookup:

```rust
// Before
map.insert(key.clone(), value);
let entry = map.get_mut(&key).unwrap();

// After (1.92+)
let entry = map.entry(key).insert_entry(value);
let value_ref = entry.get_mut();
```

Matches the `HashMap` `insert_entry` API that's been around longer.

## `BTree::append` no-overwrite semantics — 1.93 (compatibility change)

`BTreeMap::append` previously overwrote existing keys with values from the source map. In 1.93 this was changed: existing keys are preserved. **This is a behavior change for existing code, not an API addition.** If you were relying on the overwrite behavior, you need to clear the target first or explicitly merge.

Full details in the 1.93 release notes.

## `impl TryFrom<Vec<u8>> for String` — 1.87

Fallible conversion for UTF-8 validation:

```rust
let bytes: Vec<u8> = vec![0xe4, 0xbd, 0xa0, 0xe5, 0xa5, 0xbd];
let s: String = bytes.try_into()?;  // "你好"

let bad: Vec<u8> = vec![0xff, 0xfe];
let result: Result<String, _> = bad.try_into();  // Err(FromUtf8Error)
```

Equivalent to `String::from_utf8`, just discoverable through the standard conversion trait. Useful in generic contexts.
