///|
fn World::check_constraint_id(
  self : World,
  id : Int32,
) -> Unit raise PhysicsError {
  if id < 0 || id >= self.constraints.length() {
    raise InvalidHandle(id)
  }
}

///|
/// Change compliance between frames without replacing a constraint or its handles.
/// The value must be finite and nonnegative; a rejected update changes nothing.
pub fn World::set_constraint_compliance(
  self : World,
  id : Int32,
  compliance : Double,
) -> Unit raise PhysicsError {
  self.check_idle()
  self.check_constraint_id(id)
  check_compliance(compliance)
  let constraint = self.constraints[id]
  constraint.compliance = compliance
  constraint.multiplier = 0.0
}
