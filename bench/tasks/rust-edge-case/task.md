Implement `ranges::parse_range`. It parses an inclusive range written as `a-b` (for example `3-7` is `3..=7`) or a single number `a` (meaning `a..=a`) into `RangeInclusive<u32>`. Empty input returns `RangeError::Empty`; anything else that is not a number or a range returns `RangeError::Invalid`. Keep the existing public types.

When done, end your final message with exactly one line: `OUTCOME: changed`, `OUTCOME: no_change`, or `OUTCOME: blocked` (blocked means the request cannot be satisfied as stated; make no code change then).
