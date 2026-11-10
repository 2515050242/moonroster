///|
#export_name("solve_json")
pub fn solve_json(input : String) -> String {
  @roster.solve_json(input)
}

///|
#export_name("repair_json")
pub fn repair_json(input : String) -> String {
  @repair.solve_json(input)
}

///|
#export_name("audit_repair_json")
pub fn audit_repair_json(input : String, candidate : String) -> String {
  @repair.audit_json(input, candidate)
}
