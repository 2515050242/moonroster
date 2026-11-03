///|
fn candidates(s : Search, course_index : Int32) -> Array[Placement] {
  let course = s.problem.courses[course_index]
  let result : Array[Placement] = []
  for slot_index, slot in s.problem.slots {
    if !course.allowed_slots.contains(slot.id) {
      continue
    }
    if course.locked_slot is Some(id) && id != slot.id {
      continue
    }
    for room_index, room in s.problem.rooms {
      if room.capacity < course.size {
        continue
      }
      if course.locked_room is Some(id) && id != room.id {
        continue
      }
      let mut conflict = false
      for current in s.assigned {
        match current {
          Some(placed) =>
            if placed.slot == slot_index {
              let other = s.problem.courses[placed.course]
              if placed.room == room_index ||
                other.teacher == course.teacher ||
                other.group == course.group {
                conflict = true
              }
            }
          None => ()
        }
      }
      if !conflict {
        result.push({
          course: course_index,
          slot: slot_index,
          room: room_index,
        })
      }
    }
  }
  result
}

///|
fn solve(s : Search, depth : Int32) -> Bool {
  if depth == s.problem.courses.length() {
    return true
  }
  if s.nodes >= s.problem.node_limit {
    s.truncated = true
    return false
  }
  s.nodes += 1
  let mut chosen = -1
  let mut options : Array[Placement] = []
  for index in 0..<s.problem.courses.length() {
    if s.assigned[index] is None {
      let available = candidates(s, index)
      if chosen == -1 || available.length() < options.length() {
        chosen = index
        options = available
      }
    }
  }
  if chosen == -1 {
    return true
  }
  for candidate in options {
    s.assigned[chosen] = Some(candidate)
    if solve(s, depth + 1) {
      return true
    }
    s.assigned[chosen] = None
    if s.truncated {
      return false
    }
  }
  false
}
