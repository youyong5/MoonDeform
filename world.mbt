///|
pub fn World::new(config~ : Config = Config::new()) -> World raise PhysicsError {
  if !finite_vec(config.gravity) ||
    config.substeps < 1 ||
    config.substeps > 128 ||
    config.iterations < 1 ||
    config.iterations > 128 ||
    !finite(config.damping) ||
    config.damping < 0.0 ||
    !finite(config.restitution) ||
    config.restitution < 0.0 ||
    config.restitution > 1.0 ||
    !finite(config.friction) ||
    config.friction < 0.0 ||
    config.friction > 1.0 {
    raise InvalidInput("invalid solver configuration")
  }
  {
    config,
    particles: [],
    constraints: [],
    colliders: [],
    elapsed: 0.0,
    busy: false,
  }
}

///|
fn World::check_idle(self : World) -> Unit raise PhysicsError {
  if self.busy {
    raise InvalidInput(
      "world mutation during constraint evaluation is forbidden",
    )
  }
}

///|
fn World::check_id(self : World, id : Int32) -> Unit raise PhysicsError {
  if id < 0 || id >= self.particles.length() {
    raise InvalidHandle(id)
  }
}

///|
fn World::check_ids(
  self : World,
  ids : Array[Int32],
) -> Unit raise PhysicsError {
  for i in 0..<ids.length() {
    self.check_id(ids[i])
    for j in 0..<i {
      if ids[i] == ids[j] {
        raise InvalidInput("constraint contains duplicate particle handles")
      }
    }
  }
}

///|
fn check_compliance(c : Double) -> Unit raise PhysicsError {
  if !finite(c) || c < 0.0 {
    raise InvalidInput("compliance must be finite and nonnegative")
  }
}

///|
/// mass=0 pins a particle. Radius is used against static colliders.
pub fn World::add_particle(
  self : World,
  position : Vec2,
  mass~ : Double = 1.0,
  radius~ : Double = 0.02,
) -> Int32 raise PhysicsError {
  self.check_idle()
  if !finite_vec(position) ||
    !finite(mass) ||
    mass < 0.0 ||
    !finite(radius) ||
    radius < 0.0 {
    raise InvalidInput("invalid particle position, mass or radius")
  }
  let inv_mass = if mass == 0.0 { 0.0 } else { 1.0 / mass }
  if !finite(inv_mass) {
    raise InvalidInput("mass is too small")
  }
  let id = self.particles.length()
  self.particles.push({
    position,
    inv_mass,
    radius,
    velocity: Vec2::new(0.0, 0.0),
    force: Vec2::new(0.0, 0.0),
  })
  id
}

///|
pub fn World::particle_count(self : World) -> Int32 {
  self.particles.length()
}

///|
pub fn World::constraint_count(self : World) -> Int32 {
  self.constraints.length()
}

///|
pub fn World::time(self : World) -> Double {
  self.elapsed
}

///|
pub fn World::positions(self : World) -> Array[Vec2] {
  self.particles.map(fn(p) { p.position })
}

///|
pub fn World::position(self : World, id : Int32) -> Vec2 raise PhysicsError {
  self.check_id(id)
  self.particles[id].position
}

///|
pub fn World::velocity(self : World, id : Int32) -> Vec2 raise PhysicsError {
  self.check_id(id)
  self.particles[id].velocity
}

///|
/// Teleport without introducing velocity; also works on pinned particles.
pub fn World::set_position(
  self : World,
  id : Int32,
  position : Vec2,
) -> Unit raise PhysicsError {
  self.check_idle()
  self.check_id(id)
  if !finite_vec(position) {
    raise InvalidInput("non-finite position")
  }
  self.particles[id].position = position
  self.particles[id].velocity = Vec2::new(0.0, 0.0)
}

///|
pub fn World::set_velocity(
  self : World,
  id : Int32,
  velocity : Vec2,
) -> Unit raise PhysicsError {
  self.check_idle()
  self.check_id(id)
  if !finite_vec(velocity) {
    raise InvalidInput("non-finite velocity")
  }
  if self.particles[id].inv_mass != 0.0 {
    self.particles[id].velocity = velocity
  }
}

///|
/// Force persists across this frame's substeps and is cleared on successful step.
pub fn World::apply_force(
  self : World,
  id : Int32,
  force : Vec2,
) -> Unit raise PhysicsError {
  self.check_idle()
  self.check_id(id)
  if !finite_vec(force) {
    raise InvalidInput("non-finite force")
  }
  let next = self.particles[id].force.add(force)
  if !finite_vec(next) {
    raise InvalidInput("force overflow")
  }
  self.particles[id].force = next
}

///|
fn World::insert_constraint(
  self : World,
  ids : Array[Int32],
  kind : ConstraintKind,
  compliance : Double,
) -> Int32 {
  let id = self.constraints.length()
  self.constraints.push({
    ids: ids.copy(),
    kind,
    compliance,
    multiplier: 0.0,
    enabled: true,
  })
  id
}

///|
/// Omitted rest_length captures the initial separation.
pub fn World::add_distance(
  self : World,
  a : Int32,
  b : Int32,
  compliance~ : Double = 0.0,
  rest_length? : Double,
) -> Int32 raise PhysicsError {
  self.check_idle()
  self.check_ids([a, b])
  check_compliance(compliance)
  let rest = rest_length.unwrap_or(
    self.particles[a].position.sub(self.particles[b].position).length(),
  )
  if !finite(rest) || rest < 0.0 {
    raise InvalidInput("invalid rest length")
  }
  self.insert_constraint([a, b], Distance(rest), compliance)
}

///|
/// Polygon vertices must form a simple consistently ordered boundary.
/// Signed area is preserved, not a guarantee against local element inversion.
pub fn World::add_area(
  self : World,
  ids : Array[Int32],
  compliance~ : Double = 0.0,
  rest_area? : Double,
) -> Int32 raise PhysicsError {
  self.check_idle()
  if ids.length() < 3 {
    raise InvalidInput("area needs at least three particles")
  }
  self.check_ids(ids)
  check_compliance(compliance)
  let rest = rest_area.unwrap_or(
    signed_area(ids.map(fn(id) { self.particles[id].position })),
  )
  if !finite(rest) || rest.abs() < 1.0e-12 {
    raise InvalidInput("area must be nonzero and finite")
  }
  self.insert_constraint(ids, Area(rest), compliance)
}

///|
/// Signed angle of (a-b, c-b), captured from the initial configuration.
pub fn World::add_bend(
  self : World,
  a : Int32,
  b : Int32,
  c : Int32,
  compliance~ : Double = 0.0,
) -> Int32 raise PhysicsError {
  self.check_idle()
  self.check_ids([a, b, c])
  check_compliance(compliance)
  let u = self.particles[a].position.sub(self.particles[b].position)
  let v = self.particles[c].position.sub(self.particles[b].position)
  if u.length() < 1.0e-10 || v.length() < 1.0e-10 {
    raise InvalidInput("bend has a zero-length arm")
  }
  self.insert_constraint(
    [a, b, c],
    Bend(@math.atan2(cross(u, v), u.dot(v))),
    compliance,
  )
}

///|
/// Public extension point: the host supplies a scalar residual and gradients.
pub fn World::add_custom(
  self : World,
  ids : Array[Int32],
  evaluate : ConstraintFunction,
  compliance~ : Double = 0.0,
) -> Int32 raise PhysicsError {
  self.check_idle()
  if ids.is_empty() {
    raise InvalidInput("custom constraint needs particles")
  }
  self.check_ids(ids)
  check_compliance(compliance)
  self.insert_constraint(ids, Custom(evaluate), compliance)
}

///|
pub fn World::set_constraint_enabled(
  self : World,
  id : Int32,
  enabled : Bool,
) -> Unit raise PhysicsError {
  self.check_idle()
  if id < 0 || id >= self.constraints.length() {
    raise InvalidHandle(id)
  }
  self.constraints[id].enabled = enabled
}

///|
/// Allowed half-space: dot(normal, position) >= offset + particle.radius.
pub fn World::add_plane(
  self : World,
  normal : Vec2,
  offset : Double,
) -> Unit raise PhysicsError {
  self.check_idle()
  let n = normal.length()
  if !finite_vec(normal) || !finite(n) || n < 1.0e-12 || !finite(offset) {
    raise InvalidInput("invalid plane")
  }
  self.colliders.push(Plane(normal.scale(1.0 / n), offset / n))
}

///|
/// Static solid circle. Particle centers remain outside radius + particle.radius.
pub fn World::add_circle(
  self : World,
  center : Vec2,
  radius : Double,
) -> Unit raise PhysicsError {
  self.check_idle()
  if !finite_vec(center) || !finite(radius) || radius <= 0.0 {
    raise InvalidInput("invalid circle")
  }
  self.colliders.push(Circle(center, radius))
}

///|
fn contact(collider : Collider, p : Vec2, radius : Double) -> (Vec2, Double) {
  match collider {
    Plane(n, offset) => (n, offset + radius - n.dot(p))
    Circle(center, r) => {
      let delta = p.sub(center)
      let length = delta.length()
      let n = if length > 1.0e-12 {
        delta.scale(1.0 / length)
      } else {
        Vec2::new(1.0, 0.0)
      }
      (n, r + radius - length)
    }
  }
}

///|
fn World::step_inner(
  self : World,
  dt : Double,
) -> StepReport raise PhysicsError {
  let h = dt / self.config.substeps.to_double()
  let drag = @math.exp(-self.config.damping * h)
  for _ in 0..<self.config.substeps {
    let previous = self.positions()
    let incoming : Array[Vec2] = []
    for p in self.particles {
      if p.inv_mass > 0.0 {
        let acceleration = self.config.gravity.add(p.force.scale(p.inv_mass))
        p.velocity = p.velocity.add(acceleration.scale(h)).scale(drag)
        p.position = p.position.add(p.velocity.scale(h))
      }
      incoming.push(p.velocity)
    }
    for c in self.constraints {
      c.multiplier = 0.0
    }
    for _ in 0..<self.config.iterations {
      for c in self.constraints {
        self.solve_constraint(c, h)
      }
      for p in self.particles {
        if p.inv_mass > 0.0 {
          for collider in self.colliders {
            let (normal, penetration) = contact(collider, p.position, p.radius)
            if penetration > 0.0 {
              p.position = p.position.add(normal.scale(penetration))
            }
          }
        }
      }
    }
    for i in 0..<self.particles.length() {
      let p = self.particles[i]
      if p.inv_mass > 0.0 {
        p.velocity = p.position.sub(previous[i]).scale(1.0 / h)
        for collider in self.colliders {
          let (normal, penetration) = contact(collider, p.position, p.radius)
          if penetration >= -1.0e-9 {
            let vn = p.velocity.dot(normal)
            let target = (-self.config.restitution * incoming[i].dot(normal)).max(
              0.0,
            )
            if vn < target {
              p.velocity = p.velocity.add(normal.scale(target - vn))
            }
            let tangent = p.velocity.sub(normal.scale(p.velocity.dot(normal)))
            p.velocity = p.velocity.sub(tangent.scale(self.config.friction))
          }
        }
      }
      if !finite_vec(p.position) || !finite_vec(p.velocity) {
        raise NumericalFailure("non-finite particle state")
      }
    }
  }
  let report = self.report_inner()
  self.elapsed += dt
  for p in self.particles {
    p.force = Vec2::new(0.0, 0.0)
  }
  { ..report, time: self.elapsed, }
}

///|
/// One explicit frame, 0 < dt <= 0.1 seconds. Errors restore particle state,
/// force accumulators, multipliers and simulation time to the frame boundary.
pub fn World::step(self : World, dt : Double) -> StepReport raise PhysicsError {
  self.check_idle()
  if !finite(dt) ||
    dt <= 0.0 ||
    dt > 0.1 ||
    dt / self.config.substeps.to_double() < 1.0e-12 {
    raise InvalidInput(
      "dt must be in (0, 0.1] with a substep of at least 1.0e-12 seconds",
    )
  }
  let positions = self.positions()
  let velocities = self.particles.map(fn(p) { p.velocity })
  let forces = self.particles.map(fn(p) { p.force })
  let multipliers = self.constraints.map(fn(c) { c.multiplier })
  let old_time = self.elapsed
  self.busy = true
  defer {
    self.busy = false
  }
  errdefer {
    for i in 0..<self.particles.length() {
      self.particles[i].position = positions[i]
      self.particles[i].velocity = velocities[i]
      self.particles[i].force = forces[i]
    }
    for i in 0..<self.constraints.length() {
      self.constraints[i].multiplier = multipliers[i]
    }
    self.elapsed = old_time
  }
  self.step_inner(dt)
}

///|
/// Residuals have different units (length, area, radians); max error is a
/// debugging statistic, not a normalized material-accuracy score.
pub fn World::report(self : World) -> StepReport raise PhysicsError {
  self.check_idle()
  self.busy = true
  defer {
    self.busy = false
  }
  self.report_inner()
}

///|
fn World::report_inner(self : World) -> StepReport raise PhysicsError {
  let mut error = 0.0
  let mut energy = 0.0
  let mut speed = 0.0
  for c in self.constraints {
    if c.enabled {
      let (v, _) = constraint_value(
        c.kind,
        c.ids.map(fn(id) { self.particles[id].position }),
      )
      if !finite(v) {
        raise NumericalFailure("non-finite diagnostic residual")
      }
      error = error.max(v.abs())
    }
  }
  for p in self.particles {
    speed = speed.max(p.velocity.length())
    if p.inv_mass > 0.0 {
      energy += 0.5 * p.velocity.dot(p.velocity) / p.inv_mass
    }
  }
  if !finite(energy) || !finite(speed) {
    raise NumericalFailure("diagnostic overflow")
  }
  {
    time: self.elapsed,
    max_constraint_error: error,
    kinetic_energy: energy,
    max_speed: speed,
    particle_count: self.particles.length(),
    constraint_count: self.constraints.length(),
  }
}
