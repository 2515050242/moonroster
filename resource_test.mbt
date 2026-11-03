///|
fn resource_problem(mode : String, expanded : Bool) -> String {
  let courses : Array[Json] = []
  for i in 0..<3 {
    let course : Json = {
      "id": Json("c\{i}"),
      "name": "Course",
      "teacher": Json(if mode == "teacher" { "same" } else { "t\{i}" }),
      "group": Json(if mode == "group" { "same" } else { "g\{i}" }),
      "size": 1,
      "allowed_slots": if expanded && i == 2 {
        ["a", "b", "c"]
      } else {
        ["a", "b"]
      },
      "locked_room": if mode == "room" {
        "r1"
      } else {
        Json((None : String?))
      },
    }
    courses.push(course)
  }
  let input : Json = {
    "rooms": [
      { "id": "r1", "name": "R1", "capacity": 10 },
      { "id": "r2", "name": "R2", "capacity": 10 },
    ],
    "slots": [
      { "id": "a", "name": "A" },
      { "id": "b", "name": "B" },
      { "id": "c", "name": "C" },
    ],
    "courses": Json(courses),
    "node_limit": 3,
  }
  input.stringify()
}

///|
test "detects restricted slot shortages before spending search budget" {
  for mode in ["teacher", "group", "room"] {
    assert_true(
      result(resource_problem(mode, false))
      is { "status": "unsatisfiable", "nodes": 0, .. },
    )
    // Adding a resource to the restricted subset makes each case solvable.
    assert_true(result(resource_problem(mode, true)) is { "status": "ok", .. })
  }
}

///|
test "resource matchings are necessary but not sufficient for scheduling" {
  // Three pairwise-conflicting courses form a triangle needing three slots,
  // even though each separate teacher/group/room relaxation has a matching.
  let input =
    #|{"rooms":[{"id":"r1","name":"R1","capacity":1},{"id":"r2","name":"R2","capacity":1}],"slots":[{"id":"a","name":"A"},{"id":"b","name":"B"}],"courses":[{"id":"c1","name":"C1","teacher":"t1","group":"g1","size":1,"allowed_slots":["a","b"],"locked_room":"r1"},{"id":"c2","name":"C2","teacher":"t1","group":"g2","size":1,"allowed_slots":["a","b"]},{"id":"c3","name":"C3","teacher":"t2","group":"g2","size":1,"allowed_slots":["a","b"],"locked_room":"r1"}],"node_limit":100}
  assert_true(result(input) is { "status": "unsatisfiable", .. })
}

///|
test "handles 64 courses and detects the missing 64th slot" {
  let slots : Array[Json] = []
  let allowed : Array[Json] = []
  let courses : Array[Json] = []
  for i in 0..<64 {
    slots.push({ "id": Json("s\{i}"), "name": Json("Slot \{i}") })
    allowed.push(Json("s\{i}"))
  }
  for i in 0..<64 {
    courses.push({
      "id": Json("c\{i}"),
      "name": "Course",
      "teacher": "same",
      "group": Json("g\{i}"),
      "size": 1,
      "allowed_slots": Json(allowed),
    })
  }
  let input : Json = {
    "rooms": [{ "id": "r", "name": "Room", "capacity": 1 }],
    "slots": Json(slots),
    "courses": Json(courses),
    "node_limit": 64,
  }
  assert_true(result(input.stringify()) is { "status": "ok", "nodes": 64, .. })
  // Keep every reference valid while reducing the domain for all courses.
  ignore(allowed.pop())
  for i in 0..<64 {
    courses[i] = {
      "id": Json("c\{i}"),
      "name": "Course",
      "teacher": "same",
      "group": Json("g\{i}"),
      "size": 1,
      "allowed_slots": Json(allowed),
    }
  }
  let input : Json = {
    "rooms": [{ "id": "r", "name": "Room", "capacity": 1 }],
    "slots": Json(slots),
    "courses": Json(courses),
    "node_limit": 64,
  }
  assert_true(
    result(input.stringify()) is { "status": "unsatisfiable", "nodes": 0, .. },
  )
}
