///|
fn validate(p : Problem) -> String? {
  if p.node_limit < 1 {
    return Some("node_limit must be positive.")
  }
  let rooms : Map[String, Bool] = Map([])
  let slots : Map[String, Bool] = Map([])
  let courses : Map[String, Bool] = Map([])
  for room in p.rooms {
    if room.id == "" || rooms.contains(room.id) {
      return Some("Room IDs must be nonempty and unique.")
    }
    if room.name == "" || room.capacity < 1 {
      return Some("Room name and positive capacity are required.")
    }
    rooms[room.id] = true
  }
  for slot in p.slots {
    if slot.id == "" || slots.contains(slot.id) {
      return Some("Slot IDs must be nonempty and unique.")
    }
    if slot.name == "" {
      return Some("Slot name is required.")
    }
    slots[slot.id] = true
  }
  for course in p.courses {
    if course.id == "" || courses.contains(course.id) {
      return Some("Course IDs must be nonempty and unique.")
    }
    if course.name == "" ||
      course.teacher == "" ||
      course.group == "" ||
      course.size < 1 {
      return Some("Course name, teacher, group and positive size are required.")
    }
    courses[course.id] = true
    let seen : Map[String, Bool] = Map([])
    for slot in course.allowed_slots {
      if !slots.contains(slot) {
        return Some("A course references an unknown slot.")
      }
      if seen.contains(slot) {
        return Some("A course contains a duplicate allowed slot.")
      }
      seen[slot] = true
    }
    match course.locked_slot {
      Some(id) =>
        if !slots.contains(id) {
          return Some("A course locks an unknown slot.")
        }
      None => ()
    }
    match course.locked_room {
      Some(id) =>
        if !rooms.contains(id) {
          return Some("A course locks an unknown room.")
        }
      None => ()
    }
  }
  None
}
