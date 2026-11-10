///|
/// Capacity available at each integer tick. A zero closes the resource.
#derive(FromJson)
pub(all) struct Resource {
  id : String
  capacity : Array[Int32]
}

///|
#derive(FromJson)
pub(all) struct Demand {
  resource : String
  units : Int32
}

///|
/// A contiguous interval [start, end) and its simultaneous resource needs.
#derive(FromJson)
pub(all) struct OptionSlot {
  start : Int32
  end : Int32
  demands : Array[Demand]
}

///|
/// Baseline is a zero-based index in options. Frozen tasks keep that index.
#derive(FromJson)
pub(all) struct Task {
  id : String
  options : Array[OptionSlot]
  baseline : Int32
  frozen : Bool
  change_cost : Int32
  after : Array[String]
}

///|
#derive(FromJson)
pub(all) struct Problem {
  horizon : Int32
  resources : Array[Resource]
  tasks : Array[Task]
  budget : Int32
}

///|
/// Choices are option indexes in input task order.
pub(all) struct Plan {
  choices : Array[Int32]
  cost : Int32
}

///|
pub(all) enum Outcome {
  Optimal(Plan)
  Feasible(Plan)
  Unknown
  Infeasible
  Invalid(String)
}

///|
pub(all) struct Report {
  outcome : Outcome
  attempts : Int32
  lower_bound : Int32
}

///|
pub(all) enum Audit {
  Valid(Int32)
  InvalidProblem(String)
  InvalidChoices
  Frozen(String)
  Precedence(String, String)
  Capacity(String, Int32, Int32, Int32)
}

///|
pub extend Resource with @json.FromJson::{from_json}

///|
pub extend Demand with @json.FromJson::{from_json}

///|
pub extend OptionSlot with @json.FromJson::{from_json}

///|
pub extend Task with @json.FromJson::{from_json}

///|
pub extend Problem with @json.FromJson::{from_json}
