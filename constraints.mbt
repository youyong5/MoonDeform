// Distance projection is adapted from PositionBasedDynamics/XPBD.cpp,
// commit 10a70bc146a97873dc3c8fef372f5217e010542e, under MIT.
// Copyright (c) 2015-present, PositionBasedDynamics contributors.
// See third_party/PositionBasedDynamics/LICENSE and docs/PROVENANCE.md.

///|
fn constraint_value(
  kind : ConstraintKind,
  p : Array[Vec2],
) -> (Double, Array[Vec2]) {
  match kind {
    Distance(rest) => {
      let delta = p[0].sub(p[1])
      let length = delta.length()
      // Unlike upstream's no-op at zero length, choose a deterministic axis.
      let n = if length > 1.0e-12 {
        delta.scale(1.0 / length)
      } else {
        Vec2::new(1.0, 0.0)
      }
      (length - rest, [n, n.scale(-1.0)])
    }
    Area(rest) => {
      let gradients : Array[Vec2] = []
      let count = p.length()
      for i in 0..<count {
        let prev = p[(i + count - 1) % count]
        let next = p[(i + 1) % count]
        gradients.push(
          Vec2::new((next.y - prev.y) * 0.5, (prev.x - next.x) * 0.5),
        )
      }
      (signed_area(p) - rest, gradients)
    }
    Bend(rest) => {
      let u = p[0].sub(p[1])
      let v = p[2].sub(p[1])
      let u2 = u.dot(u)
      let v2 = v.dot(v)
      if u2 < 1.0e-20 || v2 < 1.0e-20 {
        (0.0, [Vec2::new(0.0, 0.0), Vec2::new(0.0, 0.0), Vec2::new(0.0, 0.0)])
      } else {
        let g0 = Vec2::new(u.y / u2, -u.x / u2)
        let g2 = Vec2::new(-v.y / v2, v.x / v2)
        let angle = @math.atan2(cross(u, v), u.dot(v))
        (wrap_angle(angle - rest), [g0, g0.add(g2).scale(-1.0), g2])
      }
    }
    Custom(evaluate) => evaluate(p)
  }
}

///|
fn World::solve_constraint(
  self : World,
  c : Constraint,
  h : Double,
) -> Unit raise PhysicsError {
  if !c.enabled {
    return
  }
  let p = c.ids.map(fn(id) { self.particles[id].position })
  let (value, gradients) = constraint_value(c.kind, p)
  if gradients.length() != c.ids.length() || !finite(value) {
    raise NumericalFailure(
      "constraint evaluation has invalid value or gradient arity",
    )
  }
  let alpha = c.compliance / (h * h)
  let mut denominator = alpha
  for i in 0..<gradients.length() {
    if !finite_vec(gradients[i]) {
      raise NumericalFailure("non-finite constraint gradient")
    }
    denominator += self.particles[c.ids[i]].inv_mass *
      gradients[i].dot(gradients[i])
  }
  if !finite(denominator) {
    raise NumericalFailure("constraint denominator overflow")
  }
  if denominator <= 1.0e-20 {
    return
  }
  // XPBD: alpha_tilde = compliance / h^2; lambda accumulates per substep.
  let dl = -(value + alpha * c.multiplier) / denominator
  if !finite(dl) {
    raise NumericalFailure("constraint multiplier overflow")
  }
  c.multiplier += dl
  for i in 0..<c.ids.length() {
    let particle = self.particles[c.ids[i]]
    particle.position = particle.position.add(
      gradients[i].scale(dl * particle.inv_mass),
    )
  }
}
