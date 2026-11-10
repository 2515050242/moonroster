///|
fn make_task(
  id : String,
  cost : Int32,
  frozen : Bool,
  after : Array[String],
  units : Int32,
) -> @repair.Task {
  let demands : Array[@repair.Demand] = [{ resource: "pool", units, }]
  {
    id,
    change_cost: cost,
    frozen,
    after,
    baseline: 0,
    options: [{ start: 0, end: 2, demands, }, { start: 2, end: 4, demands, }],
  }
}

///|
fn dispatch(budget : Int32) -> @repair.Problem {
  {
    horizon: 4,
    budget,
    resources: [{ id: "pool", capacity: [1, 1, 1, 1], }],
    tasks: [
      make_task("routine", 2, false, [], 1),
      make_task("priority", 9, false, [], 1),
    ],
  }
}

///|
test "weighted repair finds cheaper changes and labels interrupted search" {
  let full = @repair.solve(dispatch(100))
  guard full.outcome is Optimal(plan) else { fail("Expected an optimum") }
  assert_eq(plan.choices, [1, 0])
  assert_eq(plan.cost, 2)
  assert_true(@repair.audit(dispatch(100), plan.choices) is Valid(2))
  let limited = @repair.solve(dispatch(3))
  guard limited.outcome is Feasible(plan) else { fail("Expected an incumbent") }
  assert_eq(plan.cost, 9)
  assert_eq(limited.attempts, 3)
  assert_true(@repair.solve(dispatch(1)).outcome is Unknown)
}

///|
test "audit reports bad indexes, frozen tasks, dependencies and aggregate capacity" {
  let problem = dispatch(100)
  assert_true(@repair.audit(problem, [0]) is InvalidChoices)
  assert_true(@repair.audit(problem, [0, 2]) is InvalidChoices)
  assert_true(@repair.audit(problem, [0, 0]) is Capacity("pool", 0, 2, 1))
  let frozen = {
    ..problem,
    tasks: [
      make_task("first", 1, true, [], 1),
      make_task("second", 1, true, [], 1),
    ],
  }
  assert_true(@repair.audit(frozen, [0, 1]) is Frozen("second"))
  assert_true(@repair.solve(frozen).outcome is Infeasible)
  let ordered = {
    ..problem,
    tasks: [
      make_task("second", 1, false, ["first"], 1),
      make_task("first", 1, true, [], 1),
    ],
  }
  assert_true(@repair.audit(ordered, [0, 0]) is Precedence("first", "second"))
  guard @repair.solve(ordered).outcome is Optimal(plan) else {
    fail("Expected ordered repair")
  }
  assert_eq(plan.choices, [1, 0])
}

///|
test "exhaustive plans agree with branch and bound on varied resource profiles" {
  for mask in 0..<64 {
    let capacity = Array::makei(4, tick => mask / (1 << tick) % 2 + 1)
    let problem : @repair.Problem = {
      horizon: 4,
      budget: 100,
      resources: [{ id: "pool", capacity, }],
      tasks: [
        make_task("first", 7, mask / 16 % 2 == 1, [], 1),
        make_task(
          "second",
          3,
          false,
          if mask / 32 == 1 {
            ["first"]
          } else {
            []
          },
          1,
        ),
        make_task("third", 1, false, [], 1),
      ],
    }
    let mut best : Int32? = None
    for candidate in 0..<8 {
      let choices = Array::makei(3, i => candidate / (1 << i) % 2)
      if @repair.audit(problem, choices) is Valid(cost) {
        if !(best is Some(old) && old <= cost) {
          best = Some(cost)
        }
      }
    }
    match (@repair.solve(problem).outcome, best) {
      (Optimal(plan), Some(expected)) => {
        assert_eq(plan.cost, expected)
        guard @repair.audit(problem, plan.choices) is Valid(cost) else {
          fail("Invalid returned plan")
        }
        assert_eq(cost, expected)
      }
      (Infeasible, None) => ()
      _ => fail("Exhaustive reference disagrees")
    }
  }
}

///|
test "JSON rejects noninteger input and malformed choices" {
  assert_true(
    @json.parse(
      @repair.solve_json(
        "{\"horizon\":1.5,\"resources\":[],\"tasks\":[],\"budget\":1}",
      ),
    )
    is { "status": "invalid", .. },
  )
  let empty = "{\"horizon\":1,\"resources\":[],\"tasks\":[],\"budget\":1}"
  assert_true(
    @json.parse(@repair.solve_json(empty))
    is { "status": "optimal", "cost": 0, .. },
  )
  assert_true(
    @json.parse(@repair.audit_json(empty, "[0.5]"))
    is { "status": "invalid", .. },
  )
}
