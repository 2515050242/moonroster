///|
/// Run a small self-contained scheduling example.
fn main {
  let input =
    #|{"rooms":[{"id":"r1","name":"Room 101","capacity":30}],
    #|"slots":[{"id":"am","name":"Morning"},{"id":"pm","name":"Afternoon"}],
    #|"courses":[{"id":"a","name":"Databases","teacher":"Lee","group":"G1","size":20,"allowed_slots":["am","pm"]},
    #|{"id":"b","name":"Algorithms","teacher":"Lee","group":"G2","size":15,"allowed_slots":["am","pm"]}],
    #|"node_limit":1000}
  println(@roster.solve_json(input))
}
