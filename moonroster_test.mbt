///|
fn result(input : String) -> Json {
  @json.parse(@moonroster.solve_json(input)) catch {
    _ => abort("Output must be JSON")
  }
}

///|
test "finds a conflict-free placement" {
  let input =
    #|{"rooms":[{"id":"r","name":"R","capacity":40}],
    #|"slots":[{"id":"a","name":"A"},{"id":"b","name":"B"}],
    #|"courses":[
    #|{"id":"c1","name":"C1","teacher":"t","group":"g1","size":30,"allowed_slots":["a","b"]},
    #|{"id":"c2","name":"C2","teacher":"t","group":"g2","size":20,"allowed_slots":["a","b"]}],"node_limit":100}
  let value = result(input)
  assert_true(
    value
    is {
      "status": "ok",
      "assignments": [
        { "course": "c1", "slot": "a", "room": "r", .. },
        { "course": "c2", "slot": "b", "room": "r", .. },
      ],
      ..
    },
  )
}

///|
test "returns invalid for missing references and duplicates" {
  let input =
    #|{"rooms":[{"id":"r","name":"R","capacity":40},{"id":"r","name":"Other","capacity":50}],
    #|"slots":[{"id":"a","name":"A"}],"courses":[],"node_limit":50}
  assert_true(result(input) is { "status": "invalid", .. })
  let badref =
    #|{"rooms":[{"id":"r","name":"R","capacity":40}],
    #|"slots":[{"id":"a","name":"A"}],
    #|"courses":[{"id":"c","name":"C","teacher":"t","group":"g","size":20,"allowed_slots":["missing"]}],"node_limit":50}
  assert_true(result(badref) is { "status": "invalid", .. })
}

///|
test "proves impossible conflict and capacity" {
  let input =
    #|{"rooms":[{"id":"r","name":"R","capacity":30}],
    #|"slots":[{"id":"a","name":"A"}],
    #|"courses":[{"id":"c","name":"C","teacher":"t","group":"g","size":31,"allowed_slots":["a"]}],"node_limit":50}
  assert_true(result(input) is { "status": "unsatisfiable", .. })
}

///|
test "reports a bounded search as unknown" {
  let input =
    #|{"rooms":[{"id":"r","name":"R","capacity":40}],
    #|"slots":[{"id":"a","name":"A"},{"id":"b","name":"B"}],
    #|"courses":[
    #|{"id":"c1","name":"C1","teacher":"t","group":"g1","size":20,"allowed_slots":["a","b"]},
    #|{"id":"c2","name":"C2","teacher":"t","group":"g2","size":20,"allowed_slots":["a","b"]}],"node_limit":1}
  assert_true(result(input) is { "status": "unknown", "nodes": 1, .. })
}

///|
test "respects independent slot and room locks" {
  let input =
    #|{"rooms":[{"id":"r1","name":"R1","capacity":40},{"id":"r2","name":"R2","capacity":40}],
    #|"slots":[{"id":"a","name":"A"},{"id":"b","name":"B"}],
    #|"courses":[{"id":"c","name":"C","teacher":"t","group":"g","size":20,"allowed_slots":["a","b"],"locked_slot":"b","locked_room":"r2"}],"node_limit":50}
  assert_true(
    result(input)
    is {
      "status": "ok",
      "assignments": [{ "course": "c", "slot": "b", "room": "r2", .. }],
      ..
    },
  )
}

///|
test "rejects malformed JSON and invalid limits" {
  assert_true(result("{") is { "status": "invalid", .. })
  assert_true(
    result("{\"rooms\":[],\"slots\":[],\"courses\":[],\"node_limit\":0}")
    is { "status": "invalid", .. },
  )
}

///|
test "detects an impossible locked teacher conflict across rooms" {
  let input =
    #|{"rooms":[{"id":"r1","name":"R1","capacity":40},{"id":"r2","name":"R2","capacity":40}],
    #|"slots":[{"id":"a","name":"A"}],
    #|"courses":[
    #|{"id":"c1","name":"C1","teacher":"t","group":"g1","size":20,"allowed_slots":["a"],"locked_room":"r1"},
    #|{"id":"c2","name":"C2","teacher":"t","group":"g2","size":20,"allowed_slots":["a"],"locked_room":"r2"}],"node_limit":50}
  assert_true(result(input) is { "status": "unsatisfiable", .. })
}

///|
test "detects an impossible group conflict across rooms" {
  let input =
    #|{"rooms":[{"id":"r1","name":"R1","capacity":40},{"id":"r2","name":"R2","capacity":40}],
    #|"slots":[{"id":"a","name":"A"}],
    #|"courses":[
    #|{"id":"c1","name":"C1","teacher":"t1","group":"g","size":20,"allowed_slots":["a"],"locked_room":"r1"},
    #|{"id":"c2","name":"C2","teacher":"t2","group":"g","size":20,"allowed_slots":["a"],"locked_room":"r2"}],"node_limit":50}
  assert_true(result(input) is { "status": "unsatisfiable", .. })
}

///|
test "unknown locked room is invalid" {
  let input =
    #|{"rooms":[{"id":"r","name":"R","capacity":40}],"slots":[{"id":"a","name":"A"}],
    #|"courses":[{"id":"c","name":"C","teacher":"t","group":"g","size":20,"allowed_slots":["a"],"locked_room":"missing"}],"node_limit":50}
  assert_true(result(input) is { "status": "invalid", .. })
}

///|
test "an empty candidate set is impossible" {
  let input =
    #|{"rooms":[{"id":"r","name":"R","capacity":40}],"slots":[{"id":"a","name":"A"}],
    #|"courses":[{"id":"c","name":"C","teacher":"t","group":"g","size":20,"allowed_slots":[]}],"node_limit":50}
  assert_true(result(input) is { "status": "unsatisfiable", .. })
}
