use stats::median;

#[test]
fn odd_length() {
    assert_eq!(median(&[3.0, 1.0, 2.0]), Some(2.0));
}

#[test]
fn single_value() {
    assert_eq!(median(&[5.0]), Some(5.0));
}

#[test]
fn empty() {
    assert_eq!(median(&[]), None);
}
