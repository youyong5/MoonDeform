///|
fn main raise {
  let world = @deform.World::new(config=@deform.Config::new(gravity=@deform.Vec2::new(0.0, 0.0)))
  let id = world.add_particle(@deform.Vec2::new(2.0, 3.0))
  // An application-specific slider constraint; no access to solver internals.
  ignore(world.add_custom([id], fn(p) { (p[0].x - 1.0, [@deform.Vec2::new(1.0, 0.0)]) }))
  ignore(world.step(1.0 / 60.0))
  let point = world.position(id)
  if (point.x - 1.0).abs() > 0.000001 { abort("consumer projection failed") }
  println("Independent consumer OK: x=\{point.x}, y=\{point.y}")
}
