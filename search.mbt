///|
fn diagnose(s : Search) -> String? {
  for index, course in s.problem.courses {
    if candidates(s, index).is_empty() {
      if course.allowed_slots.is_empty() {
        return Some("课程 \{course.id} 没有允许的时间段。")
      }
      if course.locked_slot is Some(id) && !course.allowed_slots.contains(id) {
        return Some(
          "课程 \{course.id} 锁定的时间段不在允许范围内。",
        )
      }
      if course.locked_room is Some(id) {
        return Some("课程 \{course.id} 锁定的教室 \{id} 容量不足。")
      }
      return Some("课程 \{course.id} 没有容量足够的教室。")
    }
    for other_index in 0..<index {
      let other = s.problem.courses[other_index]
      match (course.locked_slot, other.locked_slot) {
        (Some(a), Some(b)) if a == b => {
          if course.teacher == other.teacher {
            return Some(
              "课程 \{other.id} 和 \{course.id} 将同一教师锁定在同一时间段。",
            )
          }
          if course.group == other.group {
            return Some(
              "课程 \{other.id} 和 \{course.id} 将同一班级锁定在同一时间段。",
            )
          }
          match (course.locked_room, other.locked_room) {
            (Some(first), Some(second)) if first == second =>
              return Some(
                "课程 \{other.id} 和 \{course.id} 锁定了同一时间段的同一教室。",
              )
            _ => ()
          }
        }
        _ => ()
      }
    }
  }
  matching_diagnosis(s)
}

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
