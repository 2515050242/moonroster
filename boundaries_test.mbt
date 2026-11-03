///|
fn one_course(teacher~ : String = "teacher", group~ : String = "group") -> Json {
  {
    "id": "c",
    "name": "Course",
    "teacher": Json(teacher),
    "group": Json(group),
    "size": 1,
    "allowed_slots": ["a"],
  }
}

///|
fn input_with(courses : Array[Json], limit~ : Int32 = 100) -> String {
  let input : Json = {
    "rooms": [{ "id": "r", "name": "Room", "capacity": 1 }],
    "slots": [{ "id": "a", "name": "Slot" }],
    "courses": Json(courses),
    "node_limit": Json(limit),
  }
  input.stringify()
}

///|
test "rejects ambiguous whitespace and oversized names" {
  for
    name in [
      "",
      " ",
      " teacher",
      "teacher ",
      "\tteacher",
      "teacher\n",
      "　",
      "x".repeat(129),
    ] {
    assert_true(
      result(input_with([one_course(teacher=name)]))
      is { "status": "invalid", "nodes": 0, "assignments": [], .. },
    )
    assert_true(
      result(input_with([one_course(group=name)]))
      is { "status": "invalid", .. },
    )
  }
  assert_true(
    result(input_with([one_course(teacher="张 老师")]))
    is { "status": "ok", .. },
  )
  assert_true(
    result(input_with([one_course(teacher="x".repeat(128))]))
    is { "status": "ok", .. },
  )
}

///|
test "bounds workload before search" {
  assert_true(result(input_with([], limit=100000)) is { "status": "ok", .. })
  assert_true(
    result(input_with([], limit=100001))
    is { "status": "invalid", "nodes": 0, .. },
  )
  assert_true(
    result(input_with(Array::make(65, one_course())))
    is { "status": "invalid", "nodes": 0, .. },
  )
  assert_true(
    result(" ".repeat(262145)) is { "status": "invalid", "nodes": 0, .. },
  )
  let empty = input_with([])
  assert_true(
    result(empty + " ".repeat(262144 - empty.length()))
    is { "status": "ok", .. },
  )
}

///|
test "rejects excessive JSON nesting without searching" {
  assert_true(
    result("[".repeat(32) + "0" + "]".repeat(32))
    is { "status": "invalid", "nodes": 0, .. },
  )
}

///|
test "empty work is a valid empty schedule" {
  assert_true(
    result(input_with([]))
    is { "status": "ok", "nodes": 0, "assignments": [], .. },
  )
}

///|
test "exact node budget can finish a solution" {
  assert_true(
    result(input_with([one_course()], limit=1))
    is { "status": "ok", "nodes": 1, .. },
  )
}

///|
test "repeated calls are deterministic and isolated" {
  let input = input_with([one_course()])
  let first = @moonroster.solve_json(input)
  ignore(@moonroster.solve_json("{}"))
  assert_eq(first, @moonroster.solve_json(input))
}

///|
test "integer overflow and fractional quantities are invalid" {
  let fractional_capacity =
    #|{"rooms":[{"id":"r","name":"Room","capacity":1.9}],"slots":[],"courses":[],"node_limit":10}
  let fractional_size =
    #|{"rooms":[],"slots":[],"courses":[{"id":"c","name":"Course","teacher":"t","group":"g","size":1.9,"allowed_slots":[]}],"node_limit":10}
  assert_true(result(fractional_capacity) is { "status": "invalid", .. })
  assert_true(result(fractional_size) is { "status": "invalid", .. })
  let input =
    #|{"rooms":[],"slots":[],"courses":[],"node_limit":2147483648}
  assert_true(result(input) is { "status": "invalid", .. })
  assert_true(result(input_with([], limit=-1)) is { "status": "invalid", .. })
  assert_true(
    result("{\"rooms\":[],\"slots\":[],\"courses\":[],\"node_limit\":1.5}")
    is { "status": "invalid", .. },
  )
}
