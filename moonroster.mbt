///|
priv struct Room {
  id : String
  name : String
  capacity : Int32
} derive(FromJson)

///|
priv struct Slot {
  id : String
  name : String
} derive(FromJson)

///|
priv struct Course {
  id : String
  name : String
  teacher : String
  group : String
  size : Int32
  allowed_slots : Array[String]
  locked_slot : String?
  locked_room : String?
} derive(FromJson)

///|
priv struct Problem {
  rooms : Array[Room]
  slots : Array[Slot]
  courses : Array[Course]
  node_limit : Int32
} derive(FromJson)

///|
priv struct Placement {
  course : Int32
  slot : Int32
  room : Int32
}

///|
priv struct Search {
  problem : Problem
  assigned : Array[Placement?]
  mut nodes : Int32
  mut truncated : Bool
}

///|
fn response(
  status : String,
  message : String,
  nodes : Int32,
  placements : Array[Json],
) -> String {
  let value : Json = {
    "status": Json(status),
    "message": Json(message),
    "nodes": Json(nodes),
    "assignments": Json(placements),
  }
  value.stringify()
}

///|
/// Solve a small timetable from JSON. Assignments use the supplied identifiers.
/// A node limit reports `unknown` rather than claiming the problem is impossible.
pub fn solve_json(input : String) -> String {
  let json = @json.parse(input) catch {
    _ => return response("invalid", "Invalid JSON.", 0, [])
  }
  let problem : Problem = @json.from_json(json) catch {
    _ => return response("invalid", "Invalid input fields or types.", 0, [])
  }
  match validate(problem) {
    Some(message) => return response("invalid", message, 0, [])
    None => ()
  }
  let search : Search = {
    problem,
    assigned: Array::make(problem.courses.length(), None),
    nodes: 0,
    truncated: false,
  }
  if solve(search, 0) {
    let placements : Array[Json] = []
    for item in search.assigned {
      match item {
        Some(p) => {
          let item : Json = {
            "course": Json(problem.courses[p.course].id),
            "slot": Json(problem.slots[p.slot].id),
            "room": Json(problem.rooms[p.room].id),
          }
          placements.push(item)
        }
        None => ()
      }
    }
    response("ok", "A feasible timetable was found.", search.nodes, placements)
  } else if search.truncated {
    response(
      "unknown",
      "Search limit reached; feasibility is unknown.",
      search.nodes,
      [],
    )
  } else {
    response(
      "unsatisfiable",
      "No timetable satisfies the given constraints.",
      search.nodes,
      [],
    )
  }
}
