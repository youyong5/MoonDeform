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

///|
/// Signed residual in this constraint's own units; disabled constraints return None.
/// This evaluates a pure callback, if present, without advancing simulation time.
pub fn World::constraint_residual(
  self : World,
  id : Int32,
) -> Double? raise PhysicsError {
  self.check_idle()
  self.check_constraint_id(id)
  let constraint = self.constraints[id]
  if !constraint.enabled {
    return None
  }
  self.busy = true
  defer {
    self.busy = false
  }
  let (value, _) = constraint_value(
    constraint.kind,
    constraint.ids.map(fn(id) { self.particles[id].position }),
  )
  if !finite(value) {
    raise NumericalFailure("non-finite constraint residual")
  }
  Some(value)
}
