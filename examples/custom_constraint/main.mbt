///|
fn main raise {
  let world = @deform.World::new(config=@deform.Config::new(damping=0.05))
  let center = @deform.Vec2::new(0.0, 2.0)
  let radius = 1.5
  let particle = world.add_particle(
    center.add(@deform.Vec2::new(radius, 0.0)),
    mass=2.0,
  )
  // A circular guide is an equality constraint, separate from solid colliders.
  // C = (dot(d, d) - radius^2)/2, with analytic gradient d.
  // The gradient vanishes at the center: initialize away from this singularity.
  ignore(
    world.add_custom([particle], fn(points) {
      let delta = points[0].sub(center)
      ((delta.dot(delta) - radius * radius) * 0.5, [delta])
    }),
  )
  let mut max_radial_error = 0.0
  for _ in 0..<480 {
    ignore(world.step(1.0 / 120.0))
    let error = (world.position(particle).sub(center).length() - radius).abs()
    max_radial_error = max_radial_error.max(error)
  }
  if max_radial_error > 0.0000001 {
    abort("circular guide exceeded the radial error bound")
  }
  let report = world.report()
  println(
    "Circular guide: particles=\{report.particle_count}, constraints=\{report.constraint_count}",
  )
  println("time=\{report.time}; max_radial_error=\{max_radial_error}")
}
