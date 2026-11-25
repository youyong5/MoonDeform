///|
test "metadata distinguishes every public constraint category without callbacks" {
  let w = zero_world()
  let a = w.add_particle(@deform.Vec2::new(0.0, 0.0))
  let b = w.add_particle(@deform.Vec2::new(1.0, 0.0))
  let c = w.add_particle(@deform.Vec2::new(0.0, 1.0))
  let distance = w.add_distance(a, b, compliance=0.01)
  let area = w.add_area([a, b, c], compliance=0.02)
  let bend = w.add_bend(b, a, c, compliance=0.03)
  let calls = Ref(0)
  let custom = w.add_custom(
    [a],
    fn(_) {
      calls.val = calls.val + 1
      (0.0, [])
    },
    compliance=0.04,
  )
  for
    setting in [
      (distance, @deform.ConstraintType::Distance, 0.01),
      (area, @deform.ConstraintType::Area, 0.02),
      (bend, @deform.ConstraintType::Bend, 0.03),
      (custom, @deform.ConstraintType::Custom, 0.04),
    ] {
    let (id, kind, compliance) = setting
    let info = w.constraint_info(id)
    assert_eq(info.kind, kind)
    near(info.compliance, compliance)
    assert_true(info.enabled)
  }
  assert_eq(w.constraint_info(bend).particles, [b, a, c])
  assert_eq(calls.val, 0)
  near(w.time(), 0.0)
}

///|
test "metadata is detached from topology and later material changes" {
  let w = zero_world()
  let a = w.add_particle(@deform.Vec2::new(0.0, 0.0))
  let b = w.add_particle(@deform.Vec2::new(1.0, 0.0))
  let c = w.add_distance(a, b, compliance=0.01)
  let snapshot = w.constraint_info(c)
  snapshot.particles[0] = 999
  w.set_constraint_compliance(c, 0.02)
  w.set_constraint_enabled(c, false)
  let latest = w.constraint_info(c)
  assert_eq(latest.particles, [a, b])
  near(snapshot.compliance, 0.01)
  assert_true(snapshot.enabled)
  near(latest.compliance, 0.02)
  assert_true(!latest.enabled)
  near(w.time(), 0.0)
}

///|
test "metadata validates handles and rejects callback reentry without poisoning state" {
  let w = zero_world()
  let p = w.add_particle(@deform.Vec2::new(0.0, 0.0))
  let blocked = Ref(false)
  let c = w.add_custom([p], fn(points) {
    blocked.val = try {
      ignore(w.constraint_info(0))
      false
    } catch {
      _ => true
    }
    (points[0].x, [@deform.Vec2::new(1.0, 0.0)])
  })
  for id in [-1, 99] {
    assert_true(
      try {
        ignore(w.constraint_info(id))
        false
      } catch {
        _ => true
      },
    )
  }
  ignore(w.constraint_residual(c))
  assert_true(blocked.val)
  assert_eq(w.constraint_info(c).particles, [p])
  ignore(w.step(0.01))
  near(w.time(), 0.01)
}
