///|
#derive(FromJson)
priv struct Room {
  id : String
  name : String
  capacity : Int32
}

///|
#derive(FromJson)
priv struct Slot {
  id : String
  name : String
}

///|
#derive(FromJson)
priv struct Course {
  id : String
  name : String
  teacher : String
  group : String
  size : Int32
  allowed_slots : Array[String]
  locked_slot : String?
  locked_room : String?
}

///|
#derive(FromJson)
priv struct Problem {
  rooms : Array[Room]
  slots : Array[Slot]
  courses : Array[Course]
  node_limit : Int32
}

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
  if input.length() > 262144 {
    return response(
      "invalid",
      "输入不能超过 262144 个 UTF-16 码元。",
      0,
      [],
    )
  }
  let json = @json.parse(input, max_nesting_depth=16) catch {
    _ => return response("invalid", "Invalid JSON.", 0, [])
  }
  if !valid_numbers(json) {
    return response(
      "invalid",
      "搜索上限、容量和人数必须是范围内的正整数。",
      0,
      [],
    )
  }
  normalize_locks(json)
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
  match diagnose(search) {
    Some(message) => return response("unsatisfiable", message, 0, [])
    None => ()
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
    response(
      "ok",
      "已找到满足约束的排程。",
      search.nodes,
      placements,
    )
  } else if search.truncated {
    response(
      "unknown",
      "已达到搜索上限，尚无法判断是否存在可行排程。",
      search.nodes,
      [],
    )
  } else {
    response(
      "unsatisfiable",
      "给定约束下不存在可行排程；请检查时段、教室和锁定条件。",
      search.nodes,
      [],
    )
  }
}
