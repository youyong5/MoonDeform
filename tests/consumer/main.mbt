///|
fn main raise {
  let world = @deform.World::new(
    config=@deform.Config::new(
      gravity=@deform.Vec2::new(0.0, 0.0),
      substeps=1,
      iterations=1,
      damping=0.0,
    ),
  )
  let id = world.add_particle(@deform.Vec2::new(2.0, 3.0))
  // An application-specific slider constraint; no access to solver internals.
  let constraint = world.add_custom([id], fn(p) {
    (p[0].x - 1.0, [@deform.Vec2::new(1.0, 0.0)])
  })
  ignore(world.step(1.0 / 60.0))
  let point = world.position(id)
  if (point.x - 1.0).abs() > 0.000001 {
    abort("consumer projection failed")
  }
  let info = world.constraint_info(constraint)
  if info.kind != @deform.ConstraintType::Custom || info.particles != [id] {
    abort("consumer metadata failed")
  }
  world.set_constraint_compliance(constraint, 0.01)
  world.set_position(id, @deform.Vec2::new(2.0, 3.0))
  ignore(world.step(0.1))
  if (world.position(id).x - 1.5).abs() > 0.000001 {
    abort("consumer runtime compliance failed")
  }
  if world.constraint_residual(constraint) != Some(0.5) {
    abort("consumer signed residual failed")
  }
  let falling = @deform.World::new()
  falling.add_plane(@deform.Vec2::new(0.0, 1.0), 0.0)
  let ring = falling.soft_ring(@deform.Vec2::new(0.0, 2.5), 0.6, 16)
  let initial_area = @deform.signed_area(
    ring.particles.map(id => falling.position(id)),
  )
  for _ in 0..<240 {
    ignore(falling.step(1.0 / 60.0))
  }
  let final_area = @deform.signed_area(
    ring.particles.map(id => falling.position(id)),
  )
  // A bounded smoke case, not a guarantee for arbitrary meshes or impacts.
  if !(final_area > initial_area * 0.95 && final_area < initial_area * 1.05) {
    abort("consumer ring area failed")
  }
  for id in ring.particles {
    let p = falling.position(id)
    if !(p.y >= 0.0 && p.y < 2.0 && p.x.abs() < 2.0) {
      abort("consumer ring plane contact failed")
    }
  }
  let report = falling.report()
  if report.particle_count != 16 || report.constraint_count != 33 ||
    (report.time - 4.0).abs() > 0.000001 {
    abort("consumer ring diagnostics failed")
  }
  println("Independent ring OK: 16 particles, 33 constraints, 240 frames")
  println("Independent consumer OK: x=\{point.x}, y=\{point.y}")
}
