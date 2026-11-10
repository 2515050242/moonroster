///|
priv struct Prepared {
  demands : Array[Array[Array[(Int32, Int32)]]]
  before : Array[Array[Int32]]
  after : Array[Array[Int32]]
}

///|
fn prepare(problem : Problem) -> Result[Prepared, String] {
  if problem.horizon < 1 ||
    problem.horizon > 128 ||
    problem.resources.length() > 32 ||
    problem.tasks.length() > 64 ||
    problem.budget < 1 ||
    problem.budget > 100000 {
    return Err("Invalid horizon, size or budget.")
  }
  let resources : Map[String, Int32] = Map([])
  for i, r in problem.resources {
    if r.id.is_empty() ||
      resources.contains(r.id) ||
      r.capacity.length() != problem.horizon ||
      r.capacity.any(c => c < 0 || c > 100000) {
      return Err("Invalid resource: " + r.id)
    }
    resources[r.id] = i
  }
  let tasks : Map[String, Int32] = Map([])
  for i, t in problem.tasks {
    if t.id.is_empty() ||
      tasks.contains(t.id) ||
      t.options.length() > 64 ||
      t.baseline < 0 ||
      t.baseline >= t.options.length() ||
      t.change_cost < 1 ||
      t.change_cost > 100000 {
      return Err("Invalid task or baseline: " + t.id)
    }
    tasks[t.id] = i
  }
  let demands : Array[Array[Array[(Int32, Int32)]]] = []
  let before : Array[Array[Int32]] = problem.tasks.map(_ => [])
  let after : Array[Array[Int32]] = problem.tasks.map(_ => [])
  for i, task in problem.tasks {
    let options : Array[Array[(Int32, Int32)]] = []
    for option in task.options {
      if option.start < 0 ||
        option.end > problem.horizon ||
        option.start >= option.end ||
        option.demands.length() > problem.resources.length() {
        return Err("Invalid interval or demand count: " + task.id)
      }
      let indexed : Array[(Int32, Int32)] = []
      let seen : Map[Int32, Bool] = Map([])
      for demand in option.demands {
        guard resources.get(demand.resource) is Some(r) else {
          return Err("Unknown resource: " + demand.resource)
        }
        if seen.contains(r) || demand.units < 1 || demand.units > 100000 {
          return Err("Invalid or duplicate demand: " + demand.resource)
        }
        seen[r] = true
        indexed.push((r, demand.units))
      }
      options.push(indexed)
    }
    demands.push(options)
    let seen : Map[Int32, Bool] = Map([])
    for predecessor in task.after {
      guard tasks.get(predecessor) is Some(j) else {
        return Err("Unknown predecessor: " + predecessor)
      }
      if i == j || seen.contains(j) {
        return Err("Invalid or duplicate predecessor: " + predecessor)
      }
      seen[j] = true
      before[i].push(j)
      after[j].push(i)
    }
  }
  Ok({ demands, before, after, })
}
