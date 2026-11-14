use stats::median;

#[test]
fn even_length_is_mean_of_middle_pair() {
    assert_eq!(median(&[4.0, 1.0, 3.0, 2.0]), Some(2.5));
}

#[test]
fn even_length_pair() {
    assert_eq!(median(&[10.0, 20.0]), Some(15.0));
}

#[test]
fn odd_length_still_works() {
    assert_eq!(median(&[9.0, 1.0, 5.0]), Some(5.0));
}
