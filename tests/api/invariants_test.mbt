///|
test "free fall converges toward the analytic trajectory with smaller substeps" {
  let errors : Array[Double] = []
  for substeps in [1, 4] {
    let w = @deform.World::new(
      config=@deform.Config::new(
        gravity=@deform.Vec2::new(0.0, -10.0),
        substeps~,
        iterations=1,
        damping=0.0,
      ),
    )
    let p = w.add_particle(@deform.Vec2::new(0.0, 10.0))
    w.set_velocity(p, @deform.Vec2::new(2.0, 3.0))
    for _ in 0..<50 {
      ignore(w.step(0.02))
    }
    // Continuous reference at t=1: y=10+3*t-10*t^2/2=8, vy=-7.
    near(w.position(p).x, 2.0)
    near(w.velocity(p).y, -7.0)
    near(w.time(), 1.0)
    errors.push((w.position(p).y - 8.0).abs())
  }
  assert_true(errors[0] > 0.0 && errors[0] <= 0.101)
  assert_true(errors[1] <= errors[0] * 0.26)
}

///|
test "internal projections preserve total linear momentum across many frames" {
  let w = zero_world(substeps=2, iterations=4)
  let a = w.add_particle(@deform.Vec2::new(0.0, 0.0), mass=1.0)
  let b = w.add_particle(@deform.Vec2::new(1.5, 0.0), mass=2.0)
  w.set_velocity(a, @deform.Vec2::new(2.0, 1.0))
  w.set_velocity(b, @deform.Vec2::new(-0.5, 0.25))
  ignore(w.add_distance(a, b, rest_length=1.0, compliance=0.001))
  for _ in 0..<60 {
    ignore(w.step(0.01))
    let momentum = w.velocity(a).add(w.velocity(b).scale(2.0))
    // Only internal forces: P=(1*2+2*(-0.5), 1*1+2*0.25).
    near(momentum.x, 1.0)
    near(momentum.y, 1.5)
  }
  let center = w.position(a).add(w.position(b).scale(2.0)).scale(1.0 / 3.0)
  near(center.x, 1.2)
  near(center.y, 0.3)
}

///|
test "contact damping separates tangent attenuation from normal restitution" {
  let w = @deform.World::new(
    config=@deform.Config::new(
      gravity=@deform.Vec2::new(0.0, 0.0),
      substeps=1,
      iterations=1,
      damping=0.0,
      restitution=0.5,
      friction=0.25,
    ),
  )
  w.add_plane(@deform.Vec2::new(0.0, 1.0), 0.0)
  let p = w.add_particle(@deform.Vec2::new(0.0, 0.3), mass=2.0, radius=0.2)
  w.set_velocity(p, @deform.Vec2::new(3.0, -2.0))
  let initial_energy = w.report().kinetic_energy
  let report = w.step(0.1)
  near(w.position(p).y, 0.2)
  near(w.velocity(p).x, 2.25)
  near(w.velocity(p).y, 1.0)
  // K = m/2 * ((3*(1-0.25))^2 + (2*0.5)^2) = 6.0625.
  near(report.kinetic_energy, 6.0625)
  assert_true(report.kinetic_energy < initial_energy)
}

///|
test "residual scaling preserves custom compliance response when scaled squared" {
  for scale in [0.1, 1.0, 10.0] {
    let w = zero_world(iterations=8)
    let p = w.add_particle(@deform.Vec2::new(2.0, 3.0))
    ignore(
      w.add_custom(
        [p],
        fn(points) {
          ((points[0].x - 1.0) * scale, [@deform.Vec2::new(scale, 0.0)])
        },
        compliance=0.01 * scale * scale,
      ),
    )
    ignore(w.step(0.1))
    // Analytic one-particle compliant projection: x = 2 - 1/(1+0.01/0.1^2).
    near(w.position(p).x, 1.5)
    near(w.position(p).y, 3.0)
  }
}
