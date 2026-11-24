///|
/// Build an anchored rope. Bending stiffness is independent of stretch stiffness.
pub fn World::rope(
  self : World,
  start : Vec2,
  end : Vec2,
  segments : Int32,
  mass~ : Double = 1.0,
  compliance~ : Double = 0.00001,
  bend_compliance~ : Double = 0.01,
) -> Body raise PhysicsError {
  self.check_idle()
  let old_particles = self.particles.length()
  let old_constraints = self.constraints.length()
  errdefer {
    while self.constraints.length() > old_constraints {
      ignore(self.constraints.pop())
    }
    while self.particles.length() > old_particles {
      ignore(self.particles.pop())
    }
  }
  if segments < 1 ||
    segments > 10000 ||
    !finite_vec(start) ||
    !finite_vec(end) ||
    !finite(mass) ||
    mass <= 0.0 ||
    !finite(1.0 / mass) ||
    end.sub(start).length() < 0.000001 {
    raise InvalidInput("invalid rope parameters")
  }
  check_compliance(compliance)
  check_compliance(bend_compliance)
  let ids : Array[Int32] = []
  let constraints : Array[Int32] = []
  let edges : Array[(Int32, Int32)] = []
  for i in 0..<=segments {
    let p = start.add(
      end.sub(start).scale(i.to_double() / segments.to_double()),
    )
    ids.push(self.add_particle(p, mass=if i == 0 { 0.0 } else { mass }))
  }
  for i in 0..<segments {
    constraints.push(self.add_distance(ids[i], ids[i + 1], compliance~))
    edges.push((ids[i], ids[i + 1]))
  }
  for i in 1..<segments {
    constraints.push(
      self.add_bend(ids[i - 1], ids[i], ids[i + 1], compliance=bend_compliance),
    )
  }
  { particles: ids, constraints, edges, }
}

///|
/// A planar triangular lattice with pinned top corners. Each triangle has its
/// own signed-area constraint, so shear/stretch and area control are separate.
pub fn World::grid(
  self : World,
  origin : Vec2,
  columns : Int32,
  rows : Int32,
  spacing : Double,
  mass~ : Double = 1.0,
  compliance~ : Double = 0.0001,
  area_compliance~ : Double = 0.00001,
) -> Body raise PhysicsError {
  self.check_idle()
  let old_particles = self.particles.length()
  let old_constraints = self.constraints.length()
  errdefer {
    while self.constraints.length() > old_constraints {
      ignore(self.constraints.pop())
    }
    while self.particles.length() > old_particles {
      ignore(self.particles.pop())
    }
  }
  if columns < 2 ||
    rows < 2 ||
    columns > 200 ||
    rows > 200 ||
    !finite_vec(origin) ||
    !finite(spacing) ||
    spacing < 0.000001 ||
    !finite(mass) ||
    mass <= 0.0 ||
    !finite(1.0 / mass) {
    raise InvalidInput("invalid grid parameters")
  }
  check_compliance(compliance)
  check_compliance(area_compliance)
  let ids : Array[Int32] = []
  let constraints : Array[Int32] = []
  let edges : Array[(Int32, Int32)] = []
  for y in 0..<rows {
    for x in 0..<columns {
      let p = origin.add(
        Vec2::new(x.to_double() * spacing, -y.to_double() * spacing),
      )
      let pinned = y == 0 && (x == 0 || x == columns - 1)
      ids.push(self.add_particle(p, mass=if pinned { 0.0 } else { mass }))
    }
  }
  for y in 0..<rows {
    for x in 0..<columns {
      let a = ids[y * columns + x]
      if x + 1 < columns {
        let b = ids[y * columns + x + 1]
        constraints.push(self.add_distance(a, b, compliance~))
        edges.push((a, b))
      }
      if y + 1 < rows {
        let b = ids[(y + 1) * columns + x]
        constraints.push(self.add_distance(a, b, compliance~))
        edges.push((a, b))
      }
      if x + 1 < columns && y + 1 < rows {
        let b = ids[y * columns + x + 1]
        let c = ids[(y + 1) * columns + x]
        let d = ids[(y + 1) * columns + x + 1]
        constraints.push(self.add_distance(a, d, compliance~))
        edges.push((a, d))
        constraints.push(self.add_area([a, b, d], compliance=area_compliance))
        constraints.push(self.add_area([a, d, c], compliance=area_compliance))
      }
    }
  }
  { particles: ids, constraints, edges, }
}

///|
/// A closed elastic polygon with a global signed-area target. This models a
/// lightweight planar soft body, not a volumetric FEM solid or a fluid.
pub fn World::soft_ring(
  self : World,
  center : Vec2,
  radius : Double,
  count : Int32,
  mass~ : Double = 1.0,
  compliance~ : Double = 0.0001,
  area_compliance~ : Double = 0.000001,
  bend_compliance~ : Double = 0.01,
) -> Body raise PhysicsError {
  self.check_idle()
  let old_particles = self.particles.length()
  let old_constraints = self.constraints.length()
  errdefer {
    while self.constraints.length() > old_constraints {
      ignore(self.constraints.pop())
    }
    while self.particles.length() > old_particles {
      ignore(self.particles.pop())
    }
  }
  if count < 4 ||
    count > 10000 ||
    !finite_vec(center) ||
    !finite(radius) ||
    radius < 0.000001 ||
    !finite(mass) ||
    mass <= 0.0 ||
    !finite(1.0 / mass) {
    raise InvalidInput("invalid soft-ring parameters")
  }
  check_compliance(compliance)
  check_compliance(area_compliance)
  check_compliance(bend_compliance)
  let ids : Array[Int32] = []
  let constraints : Array[Int32] = []
  let edges : Array[(Int32, Int32)] = []
  for i in 0..<count {
    let angle = i.to_double() * 6.283185307179586 / count.to_double()
    ids.push(
      self.add_particle(
        center.add(
          Vec2::new(radius * @math.cos(angle), radius * @math.sin(angle)),
        ),
        mass~,
      ),
    )
  }
  for i in 0..<count {
    let a = ids[i]
    let b = ids[(i + 1) % count]
    constraints.push(self.add_distance(a, b, compliance~))
    constraints.push(
      self.add_bend(
        ids[(i + count - 1) % count],
        a,
        b,
        compliance=bend_compliance,
      ),
    )
    edges.push((a, b))
  }
  constraints.push(self.add_area(ids, compliance=area_compliance))
  { particles: ids, constraints, edges, }
}
