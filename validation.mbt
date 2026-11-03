///|
fn validate(p : Problem) -> String? {
  if p.node_limit < 1 || p.node_limit > 100000 {
    return Some("node_limit 必须在 1 到 100000 之间。")
  }
  if p.courses.length() > 64 || p.slots.length() > 64 || p.rooms.length() > 16 {
    return Some(
      "单次排程最多支持 64 项课程、64 个时段和 16 个场地。",
    )
  }
  let rooms : Map[String, Bool] = Map([])
  let slots : Map[String, Bool] = Map([])
  let courses : Map[String, Bool] = Map([])
  for room in p.rooms {
    if !clean_text(room.id) || rooms.contains(room.id) {
      return Some(
        "场地 ID 必须唯一、长度为 1–128，且没有首尾空白。",
      )
    }
    if !clean_text(room.name) || room.capacity < 1 {
      return Some(
        "场地 \{room.id} 需要长度为 1–128 且无首尾空白的名称，以及正整数容量。",
      )
    }
    rooms[room.id] = true
  }
  for slot in p.slots {
    if !clean_text(slot.id) || slots.contains(slot.id) {
      return Some(
        "时段 ID 必须唯一、长度为 1–128，且没有首尾空白。",
      )
    }
    if !clean_text(slot.name) {
      return Some(
        "时段 \{slot.id} 需要长度为 1–128 且无首尾空白的名称。",
      )
    }
    slots[slot.id] = true
  }
  for course in p.courses {
    if !clean_text(course.id) || courses.contains(course.id) {
      return Some(
        "课程 ID 必须唯一、长度为 1–128，且没有首尾空白。",
      )
    }
    if !clean_text(course.name) ||
      !clean_text(course.teacher) ||
      !clean_text(course.group) ||
      course.size < 1 {
      return Some(
        "课程 \{course.id} 的名称、教师、班级长度须为 1–128 且无首尾空白，人数须为正整数。",
      )
    }
    courses[course.id] = true
    let seen : Map[String, Bool] = Map([])
    for slot in course.allowed_slots {
      if !slots.contains(slot) {
        return Some(
          "课程 \{course.id} 引用了不存在的时段 \{slot}。",
        )
      }
      if seen.contains(slot) {
        return Some(
          "课程 \{course.id} 重复填写了允许时段 \{slot}。",
        )
      }
      seen[slot] = true
    }
    match course.locked_slot {
      Some(id) =>
        if !slots.contains(id) {
          return Some(
            "课程 \{course.id} 锁定了不存在的时段 \{id}。",
          )
        }
      None => ()
    }
    match course.locked_room {
      Some(id) =>
        if !rooms.contains(id) {
          return Some(
            "课程 \{course.id} 锁定了不存在的场地 \{id}。",
          )
        }
      None => ()
    }
  }
  None
}

///|
// Reject surrounding whitespace instead of silently changing reference IDs.
fn clean_text(value : String) -> Bool {
  !value.is_empty() &&
  value.length() <= 128 &&
  value
  .trim(
    chars=" \t\n\r\u000B\u000C\u0085\u00A0\u1680\u2000\u2001\u2002\u2003\u2004\u2005\u2006\u2007\u2008\u2009\u200A\u2028\u2029\u202F\u205F\u3000\uFEFF",
  )
  .to_owned() ==
  value
}

///|
// An absent lock and an explicit JSON null both mean "not locked".
// Derived optional record fields otherwise try to decode null as a String.
fn normalize_locks(value : Json) -> Unit {
  if value is { "courses": Array(courses), .. } {
    for course in courses {
      if course is Object(fields) {
        for key in ["locked_slot", "locked_room"] {
          if fields.get(key) is Some(Null) {
            ignore(fields.remove(key))
          }
        }
      }
    }
  }
}

///|
// Validate before FromJson, whose integer conversion can truncate fractions.
fn positive_integer(value : Json, upper : Double) -> Bool {
  value is Number(n, ..) && n >= 1 && n <= upper && n.to_int().to_double() == n
}

///|
fn valid_numbers(value : Json) -> Bool {
  guard value
    is {
      "node_limit": limit,
      "rooms": Array(rooms),
      "courses": Array(courses),
      ..
    } else {
    return false
  }
  if !positive_integer(limit, 100000) {
    return false
  }
  for room in rooms {
    guard room is { "capacity": capacity, .. } else { return false }
    if !positive_integer(capacity, 2147483647) {
      return false
    }
  }
  for course in courses {
    guard course is { "size": size, .. } else { return false }
    if !positive_integer(size, 2147483647) {
      return false
    }
  }
  true
}
