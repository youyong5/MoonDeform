///|
test "area is invariant under a large representable translation" {
  let points = [
    @deform.Vec2::new(0.0, 0.0),
    @deform.Vec2::new(2.0, 0.0),
    @deform.Vec2::new(2.0, 1.0),
    @deform.Vec2::new(0.0, 1.0),
  ]
  let translated = points.map(fn(p) {
    p.add(@deform.Vec2::new(1000000000.0, -1000000000.0))
  })
  near(@deform.signed_area(translated), @deform.signed_area(points))
  let w = zero_world()
  let ids = translated.map(p => w.add_particle(p))
  ignore(w.add_area(ids))
  near(w.step(0.01).max_constraint_error, 0.0)
}

///|
test "concave polygon area uses signed local triangles" {
  let points = [
    @deform.Vec2::new(0.0, 0.0),
    @deform.Vec2::new(2.0, 0.0),
    @deform.Vec2::new(2.0, 2.0),
    @deform.Vec2::new(1.0, 1.0),
    @deform.Vec2::new(0.0, 2.0),
  ]
  near(@deform.signed_area(points), 3.0)
  near(@deform.signed_area([]), 0.0)
}

///|
test "vector length avoids avoidable overflow and underflow" {
  near(@deform.Vec2::new(3.0e200, 4.0e200).length() / 1.0e200, 5.0)
  near(@deform.Vec2::new(3.0e-200, 4.0e-200).length() / 1.0e-200, 5.0)
  near(@deform.Vec2::new(0.0, 0.0).length(), 0.0)
}

///|
test "plane normalization overflow rejects before inserting collider" {
  let w = zero_world()
  assert_true(
    try {
      w.add_plane(@deform.Vec2::new(1.0e-11, 0.0), 1.0e308)
      false
    } catch {
      _ => true
    },
  )
  let p = w.add_particle(@deform.Vec2::new(0.0, 0.0))
  ignore(w.step(0.01))
  near(w.position(p).x, 0.0)
}

///|
test "oversized bend geometry rejects without retaining a bad constraint" {
  let w = zero_world()
  let a = w.add_particle(@deform.Vec2::new(1.0e200, 0.0))
  let b = w.add_particle(@deform.Vec2::new(0.0, 0.0))
  let c = w.add_particle(@deform.Vec2::new(0.0, 1.0e200))
  assert_true(
    try {
      ignore(w.add_bend(a, b, c))
      false
    } catch {
      _ => true
    },
  )
  assert_eq(w.constraint_count(), 0)
}

///|
test "compliant spring under steady load approaches mg times compliance" {
  // Two different timesteps and iteration counts, same physical static target.
  for settings in [(0.01, 1), (0.02, 8)] {
    let (dt, iterations) = settings
    let w = @deform.World::new(
      config=@deform.Config::new(
        gravity=@deform.Vec2::new(0.0, -10.0),
        substeps=1,
        iterations~,
        damping=0.0,
      ),
    )
    let a = w.add_particle(@deform.Vec2::new(0.0, 0.0), mass=0.0)
    let b = w.add_particle(@deform.Vec2::new(0.0, -1.0), mass=2.0)
    ignore(w.add_distance(a, b, compliance=0.001))
    for _ in 0..<1600 {
      ignore(w.step(dt))
    }
    // Static extension: m*g*compliance = 2*10*0.001 = 0.02.
    near(w.position(b).y, -1.02, eps=0.0001)
  }
}
