///|
fn brute_cover(
  domains : Array[Array[Int32]],
  index : Int32,
  used : Array[Bool],
) -> Bool {
  if index == domains.length() {
    return true
  }
  for resource in domains[index] {
    if !used[resource] {
      used[resource] = true
      if brute_cover(domains, index + 1, used) {
        return true
      }
      used[resource] = false
    }
  }
  false
}

///|
test "all three by three matching graphs agree with independent enumeration" {
  // Each of the nine edges is independently present or absent.
  for mask in 0..<512 {
    let domains : Array[Array[Int32]] = []
    for course in 0..<3 {
      let choices : Array[Int32] = []
      for resource in 0..<3 {
        if (mask & (1 << (course * 3 + resource))) != 0 {
          choices.push(resource)
        }
      }
      domains.push(choices)
    }
    assert_eq(
      has_cover(domains, 3),
      brute_cover(domains, 0, Array::make(3, false)),
    )
  }
}

///|
test "matching repairs greedy choices and handles empty problems" {
  assert_true(has_cover([[0, 1], [0]], 2))
  assert_true(has_cover([], 0))
  assert_false(has_cover([[]], 0))
  assert_false(has_cover([[0, 1], [0, 1], [0, 1]], 3))
}
