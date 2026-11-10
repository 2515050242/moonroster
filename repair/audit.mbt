///|
/// Check a complete external plan without running the search.
/// A capacity witness carries resource id, tick, demand and capacity.
pub fn audit(problem : Problem, choices : Array[Int32]) -> Audit {
  let prepared = match prepare(problem) {
    Ok(value) => value
    Err(message) => return InvalidProblem(message)
  }
  if choices.length() != problem.tasks.length() {
    return InvalidChoices
  }
  let mut cost = 0
  for i, task in problem.tasks {
    let choice = choices[i]
    if choice < 0 || choice >= task.options.length() {
      return InvalidChoices
    }
    if choice != task.baseline {
      if task.frozen {
        return Frozen(task.id)
      }
      cost += task.change_cost
    }
  }
  let load = problem.resources.map(_ => Array::make(problem.horizon, 0))
  for i, task in problem.tasks {
    let option = task.options[choices[i]]
    for j in prepared.before[i] {
      let predecessor = problem.tasks[j]
      if predecessor.options[choices[j]].end > option.start {
        return Precedence(predecessor.id, task.id)
      }
    }
    for (r, units) in prepared.demands[i][choices[i]] {
      for tick in option.start..<option.end {
        load[r][tick] += units
      }
    }
  }
  for r, resource in problem.resources {
    for tick in 0..<problem.horizon {
      if load[r][tick] > resource.capacity[tick] {
        return Capacity(
          resource.id,
          tick,
          load[r][tick],
          resource.capacity[tick],
        )
      }
    }
  }
  Valid(cost)
}
