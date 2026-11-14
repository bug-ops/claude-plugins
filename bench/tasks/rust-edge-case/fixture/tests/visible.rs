use ranges::{parse_range, RangeError};

#[test]
fn range() {
    assert_eq!(parse_range("3-7"), Ok(3..=7));
}

#[test]
fn single() {
    assert_eq!(parse_range("5"), Ok(5..=5));
}

#[test]
fn garbage() {
    assert_eq!(parse_range("x"), Err(RangeError::Invalid));
}
