///|
fn main raise {
  let world = @deform.World::new()
  world.add_plane(@deform.Vec2::new(0.0, 1.0), 0.0)
  let body = world.soft_ring(@deform.Vec2::new(0.0, 2.5), 0.6, 16)
  let initial_area = @deform.signed_area(
    body.particles.map(id => world.position(id)),
  )
  for _ in 0..<240 {
    ignore(world.step(1.0 / 60.0))
  }
  let report = world.report()
  let final_area = @deform.signed_area(
    body.particles.map(id => world.position(id)),
  )
  println(
    "MoonDeform: particles=\{report.particle_count}, constraints=\{report.constraint_count}",
  )
  println(
    "time=\{report.time}; area initial=\{initial_area}, final=\{final_area}",
  )
  println(
    "max_speed=\{report.max_speed}; kinetic_energy=\{report.kinetic_energy}",
  )
}
