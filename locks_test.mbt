///|
test "null locks agree with absent locks and wrong lock types remain invalid" {
  let plain =
    #|{"rooms":[{"id":"r","name":"Room","capacity":1}],"slots":[{"id":"s","name":"Slot"}],"courses":[{"id":"c","name":"Course","teacher":"t","group":"g","size":1,"allowed_slots":["s"]}],"node_limit":1}
  let nulls =
    #|{"rooms":[{"id":"r","name":"Room","capacity":1}],"slots":[{"id":"s","name":"Slot"}],"courses":[{"id":"c","name":"Course","teacher":"t","group":"g","size":1,"allowed_slots":["s"],"locked_slot":null,"locked_room":null}],"node_limit":1}
  assert_eq(@moonroster.solve_json(plain), @moonroster.solve_json(nulls))
  let invalid =
    #|{"rooms":[{"id":"r","name":"Room","capacity":1}],"slots":[{"id":"s","name":"Slot"}],"courses":[{"id":"c","name":"Course","teacher":"t","group":"g","size":1,"allowed_slots":["s"],"locked_slot":null,"locked_room":7}],"node_limit":1}
  assert_true(result(invalid) is { "status": "invalid", "assignments": [], .. })
}
