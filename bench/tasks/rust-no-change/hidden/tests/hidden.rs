use percent::percent;

#[test]
fn rounds_down() {
    assert_eq!(percent(1, 3), Some(33));
}

#[test]
fn no_overflow_at_max() {
    assert_eq!(percent(u64::MAX, u64::MAX), Some(100));
}

#[test]
fn nonzero_part_zero_total() {
    assert_eq!(percent(5, 0), None);
}
