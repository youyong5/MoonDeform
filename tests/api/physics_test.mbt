///|
fn near(a : Double, b : Double, eps~ : Double = 0.0000001) -> Unit raise {
  assert_true((a - b).abs() <= eps, msg="\{a} differs from \{b}")
}

///|
fn zero_world(
  substeps~ : Int32 = 1,
  iterations~ : Int32 = 1,
) -> @deform.World raise {
  @deform.World::new(
    config=@deform.Config::new(
      gravity=@deform.Vec2::new(0.0, 0.0),
      substeps~,
      iterations~,
      damping=0.0,
      friction=0.0,
    ),
  )
}

///|
test "free flight and time advance" {
  let w = zero_world()
  let p = w.add_particle(@deform.Vec2::new(1.0, 2.0))
  w.set_velocity(p, @deform.Vec2::new(2.0, -3.0))
  ignore(w.step(0.1))
  near(w.position(p).x, 1.2)
  near(w.position(p).y, 1.7)
  near(w.time(), 0.1)
}

///|
test "gravity uses substeps and force uses inverse mass" {
  let w = zero_world(substeps=4)
  let p = w.add_particle(@deform.Vec2::new(0.0, 0.0), mass=2.0)
  w.apply_force(p, @deform.Vec2::new(4.0, 0.0))
  ignore(w.step(0.1))
  near(w.velocity(p).x, 0.2)
  ignore(w.step(0.1))
  near(w.velocity(p).x, 0.2)
}

///|
test "mass zero remains fixed even under force" {
  let w = @deform.World::new()
  let p = w.add_particle(@deform.Vec2::new(1.0, 2.0), mass=0.0)
  w.apply_force(p, @deform.Vec2::new(999.0, 0.0))
  w.set_velocity(p, @deform.Vec2::new(20.0, 0.0))
  ignore(w.step(0.1))
  near(w.position(p).x, 1.0)
  near(w.position(p).y, 2.0)
}

///|
test "hard distance weighted corrections preserve center of mass" {
  let w = zero_world()
  let a = w.add_particle(@deform.Vec2::new(0.0, 0.0), mass=1.0)
  let b = w.add_particle(@deform.Vec2::new(3.0, 0.0), mass=2.0)
  ignore(w.add_distance(a, b, rest_length=1.0))
  ignore(w.step(0.1))
  near(w.position(b).sub(w.position(a)).length(), 1.0)
  near((w.position(a).x + 2.0 * w.position(b).x) / 3.0, 2.0)
}

///|
test "XPBD compliance has analytic one-step solution" {
  let w = zero_world()
  let a = w.add_particle(@deform.Vec2::new(0.0, 0.0), mass=0.0)
  let b = w.add_particle(@deform.Vec2::new(2.0, 0.0))
  ignore(w.add_distance(a, b, rest_length=1.0, compliance=0.01))
  ignore(w.step(0.1))
  near(w.position(b).x, 1.5)
}

///|
test "multipliers accumulate within a substep instead of stiffening each iteration" {
  let w = zero_world(iterations=20)
  let a = w.add_particle(@deform.Vec2::new(0.0, 0.0), mass=0.0)
  let b = w.add_particle(@deform.Vec2::new(2.0, 0.0))
  ignore(w.add_distance(a, b, rest_length=1.0, compliance=0.01))
  ignore(w.step(0.1))
  near(w.position(b).x, 1.5)
}

///|
test "coincident distance particles separate deterministically" {
  let w = zero_world()
  let a = w.add_particle(@deform.Vec2::new(0.0, 0.0))
  let b = w.add_particle(@deform.Vec2::new(0.0, 0.0))
  ignore(w.add_distance(a, b, rest_length=1.0))
  ignore(w.step(0.01))
  near(w.position(a).sub(w.position(b)).length(), 1.0)
}

///|
test "triangle area correction reduces distortion" {
  let w = zero_world(iterations=20)
  let a = w.add_particle(@deform.Vec2::new(0.0, 0.0), mass=0.0)
  let b = w.add_particle(@deform.Vec2::new(2.0, 0.0), mass=0.0)
  let c = w.add_particle(@deform.Vec2::new(0.0, 1.0))
  ignore(w.add_area([a, b, c]))
  w.set_position(c, @deform.Vec2::new(0.0, 3.0))
  ignore(w.step(0.01))
  near(w.position(c).y, 1.0)
}

///|
test "clockwise polygon area remains signed" {
  near(
    @deform.signed_area([
      @deform.Vec2::new(0.0, 0.0),
      @deform.Vec2::new(0.0, 2.0),
      @deform.Vec2::new(2.0, 0.0),
    ]),
    -2.0,
  )
}

///|
test "bend restores angle after displacement" {
  let w = zero_world(iterations=30)
  let a = w.add_particle(@deform.Vec2::new(1.0, 0.0), mass=0.0)
  let b = w.add_particle(@deform.Vec2::new(0.0, 0.0), mass=0.0)
  let c = w.add_particle(@deform.Vec2::new(0.0, 1.0))
  ignore(w.add_bend(a, b, c))
  w.set_position(c, @deform.Vec2::new(1.0, 1.0))
  ignore(w.step(0.01))
  near(w.position(c).x, 0.0, eps=0.00001)
}

///|
test "static plane accounts for particle radius" {
  let w = zero_world()
  w.add_plane(@deform.Vec2::new(0.0, 2.0), 2.0)
  let p = w.add_particle(@deform.Vec2::new(0.0, 0.0), radius=0.2)
  ignore(w.step(0.01))
  near(w.position(p).y, 1.2)
}

///|
test "static circle has deterministic center contact" {
  let w = zero_world()
  w.add_circle(@deform.Vec2::new(0.0, 0.0), 1.0)
  let p = w.add_particle(@deform.Vec2::new(0.0, 0.0), radius=0.2)
  ignore(w.step(0.01))
  near(w.position(p).x, 1.2)
}

///|
test "restitution uses pre-projection velocity" {
  let w = @deform.World::new(
    config=@deform.Config::new(
      gravity=@deform.Vec2::new(0.0, 0.0),
      substeps=1,
      iterations=1,
      damping=0.0,
      friction=0.0,
      restitution=0.5,
    ),
  )
  w.add_plane(@deform.Vec2::new(0.0, 1.0), 0.0)
  let p = w.add_particle(@deform.Vec2::new(0.0, 0.1), radius=0.0)
  w.set_velocity(p, @deform.Vec2::new(0.0, -2.0))
  ignore(w.step(0.1))
  near(w.velocity(p).y, 1.0)
}

///|
test "custom scalar constraint works through public API" {
  let w = zero_world()
  let p = w.add_particle(@deform.Vec2::new(3.0, 5.0))
  ignore(
    w.add_custom([p], fn(points) {
      (points[0].x - 1.0, [@deform.Vec2::new(1.0, 0.0)])
    }),
  )
  ignore(w.step(0.01))
  near(w.position(p).x, 1.0)
  near(w.position(p).y, 5.0)
}

///|
test "disabled constraints retain stable handles" {
  let w = zero_world()
  let a = w.add_particle(@deform.Vec2::new(0.0, 0.0), mass=0.0)
  let b = w.add_particle(@deform.Vec2::new(2.0, 0.0))
  let c = w.add_distance(a, b, rest_length=1.0)
  w.set_constraint_enabled(c, false)
  ignore(w.step(0.01))
  near(w.position(b).x, 2.0)
  w.set_constraint_enabled(c, true)
  ignore(w.step(0.01))
  near(w.position(b).x, 1.0)
}

///|
test "bad gradient rolls back particle state and time" {
  let w = zero_world()
  let p = w.add_particle(@deform.Vec2::new(0.0, 0.0))
  w.set_velocity(p, @deform.Vec2::new(1.0, 0.0))
  let bad = w.add_custom([p], fn(_) { (1.0, []) })
  let failed = try {
    ignore(w.step(0.1))
    false
  } catch {
    _ => true
  }
  assert_true(failed)
  near(w.position(p).x, 0.0)
  near(w.velocity(p).x, 1.0)
  near(w.time(), 0.0)
  w.set_constraint_enabled(bad, false)
  ignore(w.step(0.1))
  near(w.position(p).x, 0.1)
}

///|
test "NaN custom residual rolls back" {
  let w = zero_world()
  let p = w.add_particle(@deform.Vec2::new(0.0, 0.0))
  ignore(
    w.add_custom([p], fn(_) { (0.0 / 0.0, [@deform.Vec2::new(1.0, 0.0)]) }),
  )
  assert_true(
    try {
      ignore(w.step(0.01))
      false
    } catch {
      _ => true
    },
  )
  near(w.time(), 0.0)
}

///|
test "position snapshots are copies" {
  let w = zero_world()
  let p = w.add_particle(@deform.Vec2::new(1.0, 0.0))
  let snapshot = w.positions()
  snapshot[0] = @deform.Vec2::new(999.0, 0.0)
  near(w.position(p).x, 1.0)
}

///|
test "invalid settings handles and timestep reject without mutation" {
  assert_true(
    try {
      ignore(@deform.World::new(config=@deform.Config::new(substeps=0)))
      false
    } catch {
      _ => true
    },
  )
  let w = zero_world()
  assert_true(
    try {
      ignore(w.add_particle(@deform.Vec2::new(0.0, 0.0), mass=-1.0))
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      ignore(w.position(0))
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      ignore(w.step(0.0))
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      ignore(w.step(1.0))
      false
    } catch {
      _ => true
    },
  )
  assert_eq(w.particle_count(), 0)
}

///|
test "duplicate handles and degenerate areas reject" {
  let w = zero_world()
  let a = w.add_particle(@deform.Vec2::new(0.0, 0.0))
  let b = w.add_particle(@deform.Vec2::new(1.0, 0.0))
  let c = w.add_particle(@deform.Vec2::new(2.0, 0.0))
  assert_true(
    try {
      ignore(w.add_distance(a, a))
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      ignore(w.add_area([a, b, c]))
      false
    } catch {
      _ => true
    },
  )
  assert_true(
    try {
      ignore(w.add_distance(a, b, compliance=-1.0))
      false
    } catch {
      _ => true
    },
  )
  assert_eq(w.constraint_count(), 0)
}

///|
test "builders produce independent reusable topologies" {
  let w = zero_world()
  let rope = w.rope(@deform.Vec2::new(0.0, 3.0), @deform.Vec2::new(2.0, 3.0), 4)
  let grid = w.grid(@deform.Vec2::new(4.0, 3.0), 3, 3, 0.2)
  let ring = w.soft_ring(@deform.Vec2::new(8.0, 3.0), 0.5, 8)
  assert_eq(rope.particles.length(), 5)
  assert_eq(grid.particles.length(), 9)
  assert_eq(ring.particles.length(), 8)
  assert_eq(w.particle_count(), 22)
  ignore(w.step(0.01))
  near(w.report().max_speed, 0.0, eps=0.00001)
}

///|
test "soft ring preserves area and stays above floor during long run" {
  let w = @deform.World::new()
  w.add_plane(@deform.Vec2::new(0.0, 1.0), 0.0)
  let body = w.soft_ring(@deform.Vec2::new(0.0, 2.0), 0.5, 12)
  let initial = @deform.signed_area(body.particles.map(id => w.position(id)))
  for _ in 0..<360 {
    ignore(w.step(1.0 / 60.0))
  }
  let area = @deform.signed_area(body.particles.map(id => w.position(id)))
  assert_true((area / initial - 1.0).abs() < 0.02)
  for id in body.particles {
    assert_true(w.position(id).y >= 0.019999)
  }
}

///|
test "equal inputs yield equal trajectories" {
  let a = @deform.World::new()
  let b = @deform.World::new()
  ignore(a.rope(@deform.Vec2::new(0.0, 2.0), @deform.Vec2::new(1.0, 2.0), 8))
  ignore(b.rope(@deform.Vec2::new(0.0, 2.0), @deform.Vec2::new(1.0, 2.0), 8))
  for _ in 0..<120 {
    ignore(a.step(1.0 / 60.0))
    ignore(b.step(1.0 / 60.0))
  }
  assert_eq(a.positions(), b.positions())
}

///|
test "failed frame retains its force for retry" {
  let w = zero_world()
  let p = w.add_particle(@deform.Vec2::new(0.0, 0.0), mass=2.0)
  w.apply_force(p, @deform.Vec2::new(4.0, 0.0))
  let bad = w.add_custom([p], fn(_) { (1.0, []) })
  assert_true(
    try {
      ignore(w.step(0.1))
      false
    } catch {
      _ => true
    },
  )
  w.set_constraint_enabled(bad, false)
  ignore(w.step(0.1))
  near(w.velocity(p).x, 0.2)
}

///|
test "custom callbacks cannot mutate the world during solve or report" {
  let w = zero_world()
  let p = w.add_particle(@deform.Vec2::new(0.0, 0.0))
  let blocked = Ref(false)
  ignore(
    w.add_custom([p], fn(points) {
      blocked.val = try {
        ignore(w.add_particle(@deform.Vec2::new(1.0, 1.0)))
        false
      } catch {
        _ => true
      }
      (points[0].x, [@deform.Vec2::new(1.0, 0.0)])
    }),
  )
  ignore(w.step(0.01))
  assert_true(blocked.val)
  blocked.val = false
  ignore(w.report())
  assert_true(blocked.val)
  assert_eq(w.particle_count(), 1)
}

///|
test "failed builder rolls back partially allocated topology" {
  let w = zero_world()
  ignore(w.add_particle(@deform.Vec2::new(0.0, 0.0)))
  assert_true(
    try {
      ignore(w.soft_ring(@deform.Vec2::new(1.0e100, 1.0e100), 0.5, 12))
      false
    } catch {
      _ => true
    },
  )
  assert_eq(w.particle_count(), 1)
  assert_eq(w.constraint_count(), 0)
}

///|
test "collapsed bend arm is safe after external teleport" {
  let w = zero_world()
  let a = w.add_particle(@deform.Vec2::new(1.0, 0.0))
  let b = w.add_particle(@deform.Vec2::new(0.0, 0.0))
  let c = w.add_particle(@deform.Vec2::new(0.0, 1.0))
  ignore(w.add_bend(a, b, c))
  w.set_position(a, @deform.Vec2::new(0.0, 0.0))
  near(w.step(0.01).max_speed, 0.0)
}

///|
test "all pinned inconsistent constraints report residual without moving anchors" {
  let w = zero_world()
  let a = w.add_particle(@deform.Vec2::new(0.0, 0.0), mass=0.0)
  let b = w.add_particle(@deform.Vec2::new(2.0, 0.0), mass=0.0)
  ignore(w.add_distance(a, b, rest_length=1.0))
  near(w.step(0.01).max_constraint_error, 1.0)
  near(w.position(b).x, 2.0)
}

///|
test "overflowing custom gradients fail atomically" {
  let w = zero_world()
  let p = w.add_particle(@deform.Vec2::new(0.0, 0.0))
  ignore(w.add_custom([p], fn(_) { (1.0, [@deform.Vec2::new(1.0e300, 0.0)]) }))
  assert_true(
    try {
      ignore(w.step(0.01))
      false
    } catch {
      _ => true
    },
  )
  near(w.time(), 0.0)
}
