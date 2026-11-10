///|
// Reject fractional numbers before the standard integer decoder can coerce them.
fn integer_tree(value : Json) -> Bool {
  match value {
    Number(n, ..) => n >= 0 && n <= 100000 && n.to_int().to_double() == n
    Array(items) => items.all(integer_tree)
    Object(fields) => {
      for _, item in fields {
        if !integer_tree(item) {
          return false
        }
      }
      true
    }
    _ => true
  }
}

///|
fn read_problem(input : String) -> Result[Problem, String] {
  if input.length() > 262144 {
    return Err("Input is too large.")
  }
  let value = @json.parse(input, max_nesting_depth=16) catch {
    _ => return Err("Invalid JSON.")
  }
  if !integer_tree(value) {
    return Err("Expected nonnegative integers up to 100000.")
  }
  let problem : Problem = @json.from_json(value) catch {
    _ => return Err("Invalid problem fields.")
  }
  Ok(problem)
}

///|
fn invalid_json(message : String) -> String {
  let value : Json = { "status": "invalid", "message": Json(message) }
  value.stringify()
}

///|
fn plan_json(
  problem : Problem,
  report : Report,
  status : String,
  plan : Plan,
) -> String {
  let changes : Array[Json] = []
  for i, task in problem.tasks {
    if plan.choices[i] != task.baseline {
      changes.push({
        "task": Json(task.id),
        "before": Json(task.baseline),
        "after": Json(plan.choices[i]),
        "cost": Json(task.change_cost),
      })
    }
  }
  let value : Json = {
    "status": Json(status),
    "choices": Json(plan.choices),
    "cost": Json(plan.cost),
    "attempts": Json(report.attempts),
    "lower_bound": Json(
      if status == "optimal" {
        plan.cost
      } else {
        report.lower_bound
      },
    ),
    "changes": Json(changes),
  }
  value.stringify()
}

///|
/// JSON adapter for solve. See docs/repair.md for fields and limits.
pub fn solve_json(input : String) -> String {
  let problem = match read_problem(input) {
    Ok(problem) => problem
    Err(message) => return invalid_json(message)
  }
  let report = solve(problem)
  let status = match report.outcome {
    Optimal(plan) => return plan_json(problem, report, "optimal", plan)
    Feasible(plan) => return plan_json(problem, report, "feasible", plan)
    Invalid(message) => return invalid_json(message)
    Unknown => "unknown"
    Infeasible => "unsatisfiable"
  }
  let value : Json = {
    "status": Json(status),
    "attempts": Json(report.attempts),
    "lower_bound": Json(report.lower_bound),
  }
  value.stringify()
}

///|
/// Audit a choices array or a solver response containing choices.
pub fn audit_json(input : String, candidate : String) -> String {
  let problem = match read_problem(input) {
    Ok(problem) => problem
    Err(message) => return invalid_json(message)
  }
  if candidate.length() > 262144 {
    return invalid_json("Candidate is too large.")
  }
  let json = @json.parse(candidate, max_nesting_depth=16) catch {
    _ => return invalid_json("Invalid candidate JSON.")
  }
  let choice_json = match json {
    { "choices": choices, .. } => choices
    _ => json
  }
  if !integer_tree(choice_json) {
    return invalid_json("Invalid choice indexes.")
  }
  let choices : Array[Int32] = @json.from_json(choice_json) catch {
    _ => return invalid_json("Expected a choices array.")
  }
  let value : Json = match audit(problem, choices) {
    Valid(cost) => { "status": "ok", "cost": Json(cost) }
    InvalidProblem(message) => return invalid_json(message)
    InvalidChoices => return invalid_json("Choice count or index is invalid.")
    Frozen(task) =>
      { "status": "conflict", "kind": "frozen", "task": Json(task) }
    Precedence(first, second) =>
      {
        "status": "conflict",
        "kind": "precedence",
        "predecessor": Json(first),
        "task": Json(second),
      }
    Capacity(resource, tick, used, available) =>
      {
        "status": "conflict",
        "kind": "capacity",
        "resource": Json(resource),
        "tick": Json(tick),
        "used": Json(used),
        "available": Json(available),
      }
  }
  value.stringify()
}
