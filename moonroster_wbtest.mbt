///|
fn reference_valid(p : Problem, assigned : Array[Placement]) -> Bool {
  if assigned.length() != p.courses.length() {
    return false
  }
  for index, item in assigned {
    if item.course != index ||
      item.slot < 0 ||
      item.slot >= p.slots.length() ||
      item.room < 0 ||
      item.room >= p.rooms.length() {
      return false
    }
    let course = p.courses[index]
    let slot = p.slots[item.slot]
    let room = p.rooms[item.room]
    if room.capacity < course.size || !course.allowed_slots.contains(slot.id) {
      return false
    }
    if course.locked_slot is Some(id) && id != slot.id {
      return false
    }
    if course.locked_room is Some(id) && id != room.id {
      return false
    }
    for prev in 0..<index {
      let other = assigned[prev]
      let other_course = p.courses[prev]
      if item.slot == other.slot &&
        (
          item.room == other.room ||
          course.teacher == other_course.teacher ||
          course.group == other_course.group
        ) {
        return false
      }
    }
  }
  true
}

///|
fn reference_exists(p : Problem) -> Bool {
  // Exhaustively consider every room and time for each of three courses.
  for a in 0..<4 {
    for b in 0..<4 {
      for c in 0..<4 {
        let choices : Array[Placement] = [
          { course: 0, slot: a / 2, room: a % 2, },
          { course: 1, slot: b / 2, room: b % 2, },
          { course: 2, slot: c / 2, room: c % 2, },
        ]
        if reference_valid(p, choices) {
          return true
        }
      }
    }
  }
  false
}

///|
test "small problems agree with exhaustive enumeration" {
  for scenario in 0..<128 {
    let courses : Array[Course] = []
    for i in 0..<3 {
      courses.push({
        id: "c\{i}",
        name: "Course",
        teacher: if scenario % 2 == 0 {
          "same"
        } else {
          "t\{i}"
        },
        group: if scenario / 2 % 2 == 0 {
          "same"
        } else {
          "g\{i}"
        },
        size: if scenario / 4 % 2 == 0 && i == 0 {
          2
        } else {
          1
        },
        allowed_slots: if scenario / 8 % 2 == 0 && i == 0 {
          ["a"]
        } else {
          ["a", "b"]
        },
        locked_slot: if scenario / 16 % 2 == 0 && i == 1 {
          Some("a")
        } else {
          None
        },
        locked_room: if scenario / 32 % 2 == 0 && i == 2 {
          Some("r1")
        } else {
          None
        },
      })
    }
    if scenario >= 64 {
      courses[0] = { ..courses[0], allowed_slots: [], }
    }
    let problem : Problem = {
      rooms: [
        { id: "r1", name: "R1", capacity: 1, },
        { id: "r2", name: "R2", capacity: 2, },
      ],
      slots: [{ id: "a", name: "A", }, { id: "b", name: "B", }],
      courses,
      node_limit: 1000,
    }
    let search : Search = {
      problem,
      assigned: Array::make(3, None),
      nodes: 0,
      truncated: false,
    }
    if diagnose(search) is Some(_) {
      assert_false(reference_exists(problem))
    }
    let found = solve(search, 0)
    assert_eq(found, reference_exists(problem))
    assert_false(search.truncated)
    if found {
      let placements : Array[Placement] = []
      for item in search.assigned {
        match item {
          Some(p) => placements.push(p)
          None => ()
        }
      }
      assert_true(reference_valid(problem, placements))
    }
  }
}
