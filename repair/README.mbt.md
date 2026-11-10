# Minimum-change plan repair

This package works with named resources and candidate intervals. The legacy
timetable package is independent of this API.

```mbt check
///|
test "move a task away from a closed resource" {
  let problem : @repair.Problem = {
    horizon: 2,
    budget: 10,
    resources: [{ id: "rig", capacity: [0, 1], }],
    tasks: [
      {
        id: "measurement",
        baseline: 0,
        frozen: false,
        change_cost: 3,
        after: [],
        options: [
          { start: 0, end: 1, demands: [{ resource: "rig", units: 1, }], },
          { start: 1, end: 2, demands: [{ resource: "rig", units: 1, }], },
        ],
      },
    ],
  }
  guard @repair.solve(problem).outcome is Optimal(plan) else {
    fail("Expected repair")
  }
  assert_eq(plan.choices, [1])
  assert_true(@repair.audit(problem, plan.choices) is Valid(3))
}
```
