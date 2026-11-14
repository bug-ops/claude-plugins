`slugify` leaves runs of separators and leading or trailing hyphens: `slugify("Hello,  World!")` returns `"hello--world-"` but should return `"hello-world"`. Fix only that. Run the tests with `npm test`.

When done, end your final message with exactly one line: `OUTCOME: changed`, `OUTCOME: no_change`, or `OUTCOME: blocked` (blocked means the request cannot be satisfied as stated; make no code change then).
