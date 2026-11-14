The `stats` crate's `median` returns a wrong value for some inputs: `median(&[1.0, 2.0, 3.0, 4.0])` should be `2.5` but returns `3.0`. Fix the bug, keeping the public API unchanged.

When done, end your final message with exactly one line: `OUTCOME: changed`, `OUTCOME: no_change`, or `OUTCOME: blocked` (blocked means the request cannot be satisfied as stated; make no code change then).
