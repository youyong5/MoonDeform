///|
test "runtime compliance changes preserve topology and match analytic response" {
  let w = zero_world()
  let a = w.add_particle(@deform.Vec2::new(0.0, 0.0), mass=0.0)
  let b = w.add_particle(@deform.Vec2::new(2.0, 0.0))
  let c = w.add_distance(a, b, rest_length=1.0)
  ignore(w.step(0.1))
  near(w.position(b).x, 1.0)
  w.set_position(b, @deform.Vec2::new(2.0, 0.0))
  w.set_constraint_compliance(c, 0.01)
  ignore(w.step(0.1))
  near(w.position(b).x, 1.5)
  w.set_position(b, @deform.Vec2::new(2.0, 0.0))
  w.set_constraint_compliance(c, 0.0)
  ignore(w.step(0.1))
  near(w.position(b).x, 1.0)
  assert_eq(w.particle_count(), 2)
  assert_eq(w.constraint_count(), 1)
}

///|
test "rejected compliance updates preserve the previous material" {
  let w = zero_world()
  let a = w.add_particle(@deform.Vec2::new(0.0, 0.0), mass=0.0)
  let b = w.add_particle(@deform.Vec2::new(2.0, 0.0))
  let c = w.add_distance(a, b, rest_length=1.0, compliance=0.01)
  for invalid in [-1.0, 0.0 / 0.0, 1.0 / 0.0] {
    assert_true(
      try {
        w.set_constraint_compliance(c, invalid)
        false
      } catch {
        _ => true
      },
    )
  }
  for invalid in [-1, 99] {
    assert_true(
      try {
        w.set_constraint_compliance(invalid, 0.0)
        false
      } catch {
        _ => true
      },
    )
  }
  ignore(w.step(0.1))
  near(w.position(b).x, 1.5)
}

///|
test "disabled constraints can be retuned before enabling" {
  let w = zero_world()
  let p = w.add_particle(@deform.Vec2::new(2.0, 0.0))
  let c = w.add_custom([p], fn(points) {
    (points[0].x - 1.0, [@deform.Vec2::new(1.0, 0.0)])
  })
  w.set_constraint_enabled(c, false)
  w.set_constraint_compliance(c, 0.01)
  ignore(w.step(0.1))
  near(w.position(p).x, 2.0)
  w.set_constraint_enabled(c, true)
  ignore(w.step(0.1))
  near(w.position(p).x, 1.5)
}

///|
test "custom callbacks cannot retune constraints during solve" {
  let w = zero_world()
  let p = w.add_particle(@deform.Vec2::new(2.0, 0.0))
  let blocked = Ref(false)
  ignore(
    w.add_custom([p], fn(points) {
      blocked.val = try {
        w.set_constraint_compliance(0, 1.0)
        false
      } catch {
        _ => true
      }
      (points[0].x - 1.0, [@deform.Vec2::new(1.0, 0.0)])
    }),
  )
  ignore(w.step(0.01))
  assert_true(blocked.val)
  near(w.position(p).x, 1.0)
}
