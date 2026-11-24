///|
fn main raise {
  let world = @deform.World::new(
    config=@deform.Config::new(
      gravity=@deform.Vec2::new(0.0, -10.0),
      substeps=1,
      iterations=8,
      damping=0.0,
    ),
  )
  let anchor = world.add_particle(@deform.Vec2::new(0.0, 0.0), mass=0.0)
  let bob = world.add_particle(@deform.Vec2::new(0.0, -1.0), mass=2.0)
  let spring = world.add_distance(anchor, bob)
  for setting in [(0.001, 0.02), (0.002, 0.04)] {
    let (compliance, expected) = setting
    world.set_constraint_compliance(spring, compliance)
    for _ in 0..<1600 {
      ignore(world.step(0.01))
    }
    let extension = match world.constraint_residual(spring) {
      Some(value) => value
      None => abort("the spring must remain enabled")
    }
    // Static extension = mass * gravity magnitude * compliance.
    if (extension - expected).abs() > 0.0001 {
      abort("runtime material failed the static extension reference")
    }
    println("compliance=\{compliance}; extension=\{extension}")
  }
  world.set_constraint_compliance(spring, 0.0)
  ignore(world.step(0.01))
  match world.constraint_residual(spring) {
    Some(value) =>
      if value.abs() > 0.0000001 {
        abort("the final hard constraint must restore its rest length")
      }
    None => abort("the spring must remain enabled")
  }
  if world.particle_count() != 2 || world.constraint_count() != 1 {
    abort("material changes must preserve topology")
  }
  println("Runtime material OK: two particles and one stable constraint")
}
