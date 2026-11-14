use std::ops::RangeInclusive;

/// Why a range expression could not be parsed.
#[derive(Debug, PartialEq, Eq)]
pub enum RangeError {
    Empty,
    Invalid,
}

/// Parses `"a-b"` (inclusive) or a single number `"a"` into a range.
pub fn parse_range(input: &str) -> Result<RangeInclusive<u32>, RangeError> {
    let _ = input;
    todo!()
}
