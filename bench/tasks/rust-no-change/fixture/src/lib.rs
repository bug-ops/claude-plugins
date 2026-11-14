/// Returns `part` as a whole percent of `total`, capped at 100, or `None` when `total` is zero.
pub fn percent(part: u64, total: u64) -> Option<u8> {
    if total == 0 {
        return None;
    }
    let value = u128::from(part) * 100 / u128::from(total);
    Some(value.min(100) as u8)
}
