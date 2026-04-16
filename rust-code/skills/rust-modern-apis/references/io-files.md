# File I/O APIs

## `File::lock` / `File::try_lock` / `File::lock_shared` / `File::try_lock_shared` / `File::unlock` — 1.89

**Advisory file locking, now in std.** Eliminates the need for `fs2`, `fd-lock`, or `file-lock` crates for this use case.

### Why this matters

Before 1.89, advisory file locking required a third-party crate because std had no portable API. Every project that needed to prevent concurrent writes (PID files, SQLite journals without built-in locking, cache directories, daemon single-instance checks) had to pick a crate, add a dep, and worry about its maintenance status.

All of them are now replaceable with std.

### Semantics

- **Exclusive lock** (`lock`, `try_lock`): only one holder at a time. Blocks (`lock`) or returns error (`try_lock`) if contended.
- **Shared lock** (`lock_shared`, `try_lock_shared`): multiple readers, no writers. Used for read-mostly shared resources.
- **`unlock`**: explicitly release. Also happens automatically on `Drop` of the `File`.

Cross-platform: POSIX `flock` (or `fcntl` on some systems), Windows `LockFileEx`. Advisory only — processes that don't cooperatively check the lock can still modify the file.

### Single-instance daemon pattern (PID file with lock)

```rust
use std::fs::OpenOptions;
use std::io::{self, ErrorKind, Write};

fn acquire_pid_lock(pid_path: &Path) -> io::Result<File> {
    let mut file = OpenOptions::new()
        .create(true)
        .write(true)
        .truncate(true)
        .open(pid_path)?;

    match file.try_lock() {
        Ok(()) => {
            writeln!(file, "{}", std::process::id())?;
            Ok(file)  // keep holding for the rest of the process's lifetime
        }
        Err(e) if e.kind() == ErrorKind::WouldBlock => {
            Err(io::Error::new(
                ErrorKind::AddrInUse,
                "another instance is already running",
            ))
        }
        Err(e) => Err(e),
    }
}
```

The returned `File` must be kept alive for the lock to persist. On drop, the OS releases it — which also happens when the process exits, so no cleanup is needed even on crash.

### Atomic cache writes with shared read lock

```rust
// Reader: non-blocking shared lock
let mut f = File::open(&cache_path)?;
f.lock_shared()?;  // multiple readers can hold this simultaneously
let data = read_cache(&mut f)?;
f.unlock()?;  // or drop f

// Writer: blocking exclusive lock
let mut f = OpenOptions::new().write(true).open(&cache_path)?;
f.lock()?;  // waits for all readers to finish
write_cache(&mut f, new_data)?;
```

### Return type

`try_lock` returns `io::Result<()>`. When contended, the error kind is `io::ErrorKind::WouldBlock`. Match on `e.kind() == ErrorKind::WouldBlock` to distinguish "someone else has the lock" from "I/O failure".

## `io::pipe() -> io::Result<(PipeReader, PipeWriter)>` — 1.87

Anonymous pipe creation without spawning a process. Equivalent to POSIX `pipe(2)` + Windows `CreatePipe`.

```rust
let (mut reader, mut writer) = io::pipe()?;

// Often used to wire stdout/stderr of child processes
std::thread::spawn(move || writer.write_all(b"hello\n").unwrap());

let mut buf = String::new();
reader.read_to_string(&mut buf)?;
assert_eq!(buf, "hello\n");
```

`PipeReader` and `PipeWriter` convert to/from `OwnedFd`/`OwnedHandle` and `Stdio`, so they integrate naturally with `Command` piping. Replaces `os_pipe` crate for simple cases.

## `io::Seek` for `io::Take` — 1.89

`Take<T>` now implements `Seek` when `T: Seek`. Allows seeking within a bounded wrapper:

```rust
let mut f = File::open("data.bin")?;
let mut window = f.take(1024);  // first 1 KiB

window.seek(SeekFrom::Start(512))?;  // seek within the 1 KiB window
```

Useful for reading sub-ranges with a seekable view, e.g., parsing headers in fixed-size records.

## `File::set_times` / `File::set_modified` — stabilized earlier, context here

These existed pre-1.89 but are worth mentioning next to `File::lock` because daemon code often cares about both. Use for touch-like operations without shelling out.

## What's NOT in std

Things you might still want a crate for:

- **Mandatory locking** (Linux `O_NONBLOCK` + mount options) — not portable, not in std.
- **File system events** (inotify/FSEvents/ReadDirectoryChangesW) — use `notify` crate.
- **Memory-mapped files** — use `memmap2`.
- **File descriptor passing over Unix sockets** — `sendmsg`/`recvmsg` with SCM_RIGHTS is not in std.
