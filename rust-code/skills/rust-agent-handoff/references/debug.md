# rust-debugger Output Schema

```yaml
output:
  summary: "Debug investigation results"
  
  error_type: runtime  # compilation | runtime | async | memory
  
  root_cause:
    file: src/processor.rs
    line: 42
    issue: "Off-by-one error in loop bound"
    explanation: "Loop iterates len-1 times, missing last element"
  
  reproduction:
    steps:
      - "Create input with 3 elements"
      - "Call process_batch()"
      - "Observe only 2 elements processed"
    minimal_case: |
      let data = vec![1, 2, 3];
      assert_eq!(process(&data).len(), 3); // fails: returns 2
  
  solution:
    before: "for i in 0..len-1 { ... }"
    after: "for i in 0..len { ... }"
  
  regression_test: |
    #[test]
    fn test_processes_all_elements() {
        let data = vec![1, 2, 3];
        assert_eq!(process(&data).len(), 3);
    }
  
  related_issues:
    - "Similar pattern in batch_update() - verify"
```

## Field Descriptions

| Field | Required | Description |
|-------|----------|-------------|
| `summary` | yes | Brief description of debugging work |
| `error_type` | yes | Category of error |
| `root_cause` | yes | Location and explanation |
| `reproduction` | yes | Steps to reproduce |
| `solution` | yes | Before/after fix |
| `regression_test` | yes | Test to prevent regression |
| `related_issues` | no | Similar code to check |

## Error Types

| Type | Description | Tools |
|------|-------------|-------|
| `compilation` | Borrow checker, lifetimes, types | `rustc --explain`, `cargo expand` |
| `runtime` | Panics, logic errors | `RUST_BACKTRACE=1`, lldb/gdb |
| `async` | Deadlocks, task issues | `tokio-console`, timeouts |
| `memory` | Leaks, use-after-free | ASAN, valgrind, dhat |

## Common Patterns

**Borrow checker:**
- Separate mutable/immutable scopes
- Use `.clone()` to break borrow chain (last resort)
- Consider `Rc<RefCell<T>>` for shared mutability

**Lifetimes:**
- Return owned data if lifetime unclear
- Use `'static` bounds for thread spawning
- Consider `Arc` for cross-thread sharing

**Async:**
- Add timeouts to find hanging operations
- Use `spawn_blocking` for CPU work
- Never use `std::thread::sleep` in async

## Multiple Parent Sources Example

When debugging requires context from multiple sources:

```yaml
id: 2025-01-09T18-00-00-debug
parent:
  - 2025-01-09T15-30-00-developer  # Original implementation
  - 2025-01-09T16-00-00-testing    # Failing test details
  - 2025-01-09T17-00-00-performance  # Performance degradation report
agent: debug
```

Use this when:
- Investigating failures reported by testing engineer with implementation context
- Debugging performance issues (needs both performance report and implementation)
- Analyzing security vulnerability (needs security report + implementation + tests)
- Complex bugs involving multiple components from parallel work streams
