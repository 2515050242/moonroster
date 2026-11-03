///|
// A full schedule induces a matching in each relaxed resource model.
// Failure proves infeasibility; success alone never proves a schedule exists.
fn has_cover(domains : Array[Array[Int32]], resources : Int32) -> Bool {
  let owners = Array::make(resources, -1)
  for index in 0..<domains.length() {
    if !augment(index, domains, owners, Array::make(resources, false)) {
      return false
    }
  }
  true
}

///|
fn augment(
  course : Int32,
  domains : Array[Array[Int32]],
  owners : Array[Int32],
  seen : Array[Bool],
) -> Bool {
  for resource in domains[course] {
    if seen[resource] {
      continue
    }
    seen[resource] = true
    if owners[resource] == -1 ||
      augment(owners[resource], domains, owners, seen) {
      owners[resource] = course
      return true
    }
  }
  false
}

///|
fn matching_diagnosis(s : Search) -> String? {
  let placements : Array[Array[Int32]] = []
  let teachers : Map[String, Array[Array[Int32]]] = Map([])
  let groups : Map[String, Array[Array[Int32]]] = Map([])
  let room_count = s.problem.rooms.length()
  for index, course in s.problem.courses {
    let positions : Array[Int32] = []
    let slots : Array[Int32] = []
    for placement in candidates(s, index) {
      positions.push(placement.slot * room_count + placement.room)
      if !slots.contains(placement.slot) {
        slots.push(placement.slot)
      }
    }
    placements.push(positions)
    if !teachers.contains(course.teacher) {
      teachers[course.teacher] = []
    }
    if !groups.contains(course.group) {
      groups[course.group] = []
    }
    teachers[course.teacher].push(slots)
    groups[course.group].push(slots)
  }
  // Follow input order instead of Map iteration order for stable diagnostics.
  let checked_teachers : Map[String, Bool] = Map([])
  let checked_groups : Map[String, Bool] = Map([])
  for course in s.problem.courses {
    if !checked_teachers.contains(course.teacher) {
      checked_teachers[course.teacher] = true
      if !has_cover(teachers[course.teacher], s.problem.slots.length()) {
        return Some(
          "教师 \{course.teacher} 的课程无法分配到互不冲突的可用时段。",
        )
      }
    }
    if !checked_groups.contains(course.group) {
      checked_groups[course.group] = true
      if !has_cover(groups[course.group], s.problem.slots.length()) {
        return Some(
          "班级 \{course.group} 的课程无法分配到互不冲突的可用时段。",
        )
      }
    }
  }
  if !has_cover(placements, room_count * s.problem.slots.length()) {
    return Some(
      "课程的可用场地与时段组合不足，无法安排全部课程。",
    )
  }
  None
}
