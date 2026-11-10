///|
priv struct Search {
  problem : Problem
  prepared : Prepared
  domains : Array[Array[Int32]]
  order : Array[Int32]
  suffix : Array[Int32]
  load : Array[Array[Int32]]
  choices : Array[Int32]
  mut best : Plan?
  mut attempts : Int32
  mut stopped : Bool
}

///|
fn fits(s : Search, i : Int32, choice : Int32) -> Bool {
  let option = s.problem.tasks[i].options[choice]
  for j in s.prepared.before[i] {
    if s.choices[j] >= 0 &&
      s.problem.tasks[j].options[s.choices[j]].end > option.start {
      return false
    }
  }
  for j in s.prepared.after[i] {
    if s.choices[j] >= 0 &&
      option.end > s.problem.tasks[j].options[s.choices[j]].start {
      return false
    }
  }
  for (r, units) in s.prepared.demands[i][choice] {
    for tick in option.start..<option.end {
      if s.load[r][tick] + units > s.problem.resources[r].capacity[tick] {
        return false
      }
    }
  }
  true
}

///|
fn set_load(s : Search, i : Int32, choice : Int32, sign : Int32) -> Unit {
  let option = s.problem.tasks[i].options[choice]
  for (r, units) in s.prepared.demands[i][choice] {
    for tick in option.start..<option.end {
      s.load[r][tick] += sign * units
    }
  }
}

///|
fn visit(s : Search, depth : Int32, cost : Int32) -> Unit {
  if s.best is Some(plan) && cost + s.suffix[depth] >= plan.cost {
    return
  }
  if depth == s.order.length() {
    s.best = Some({ choices: s.choices.copy(), cost, })
    return
  }
  let i = s.order[depth]
  let task = s.problem.tasks[i]
  for choice in s.domains[i] {
    let next_cost = if choice == task.baseline {
      cost
    } else {
      cost + task.change_cost
    }
    if s.best is Some(plan) && next_cost + s.suffix[depth + 1] >= plan.cost {
      continue
    }
    if s.attempts == s.problem.budget {
      s.stopped = true
      return
    }
    s.attempts += 1
    if !fits(s, i, choice) {
      continue
    }
    s.choices[i] = choice
    set_load(s, i, choice, 1)
    visit(s, depth + 1, next_cost)
    set_load(s, i, choice, -1)
    s.choices[i] = -1
    if s.stopped {
      return
    }
  }
}

///|
/// Choose one option per task with minimum total change cost.
/// A budgeted result with a plan is Feasible until optimality is proved.
pub fn solve(problem : Problem) -> Report {
  let prepared = match prepare(problem) {
    Ok(value) => value
    Err(message) =>
      return { outcome: Invalid(message), attempts: 0, lower_bound: 0, }
  }
  let domains : Array[Array[Int32]] = problem.tasks.map(_ => [])
  let order : Array[Int32] = []
  let suffix = Array::make(problem.tasks.length() + 1, 0)
  let s : Search = {
    problem,
    prepared,
    domains,
    order,
    suffix,
    load: problem.resources.map(_ => Array::make(problem.horizon, 0)),
    choices: Array::make(problem.tasks.length(), -1),
    best: None,
    attempts: 0,
    stopped: false,
  }
  for i, task in problem.tasks {
    if fits(s, i, task.baseline) {
      domains[i].push(task.baseline)
    }
    if !task.frozen {
      for choice in 0..<task.options.length() {
        if choice != task.baseline && fits(s, i, choice) {
          domains[i].push(choice)
        }
      }
    }
    if domains[i].is_empty() {
      return { outcome: Infeasible, attempts: 0, lower_bound: 0, }
    }
    // Stable insertion by candidate count, with input order as the tie break.
    let mut position = order.length()
    while position > 0 &&
          domains[order[position - 1]].length() > domains[i].length() {
      position -= 1
    }
    order.insert(position, i)
  }
  for offset in 0..<order.length() {
    let depth = order.length() - 1 - offset
    let i = order[depth]
    let task = problem.tasks[i]
    suffix[depth] = suffix[depth + 1] +
      (if domains[i].contains(task.baseline) { 0 } else { task.change_cost })
  }
  visit(s, 0, 0)
  let outcome = match s.best {
    Some(plan) if s.stopped => Feasible(plan)
    Some(plan) => Optimal(plan)
    None if s.stopped => Unknown
    None => Infeasible
  }
  { outcome, attempts: s.attempts, lower_bound: suffix[0], }
}
