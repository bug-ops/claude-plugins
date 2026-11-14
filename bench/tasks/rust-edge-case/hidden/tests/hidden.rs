use ranges::{parse_range, RangeError};

#[test]
fn reversed_range_is_invalid() {
    assert_eq!(parse_range("7-3"), Err(RangeError::Invalid));
}

#[test]
fn empty_input() {
    assert_eq!(parse_range(""), Err(RangeError::Empty));
}

#[test]
fn open_ended_is_invalid() {
    assert_eq!(parse_range("3-"), Err(RangeError::Invalid));
    assert_eq!(parse_range("-3"), Err(RangeError::Invalid));
}

#[test]
fn full_u32_span() {
    assert_eq!(parse_range("0-4294967295"), Ok(0..=u32::MAX));
}

#[test]
fn overflow_is_invalid() {
    assert_eq!(parse_range("0-4294967296"), Err(RangeError::Invalid));
}
