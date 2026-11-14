use percent::percent;

#[test]
fn zero_total_is_none() {
    assert_eq!(percent(0, 0), None);
}

#[test]
fn half() {
    assert_eq!(percent(1, 2), Some(50));
}

#[test]
fn capped() {
    assert_eq!(percent(7, 3), Some(100));
}
