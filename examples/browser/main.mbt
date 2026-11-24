///|
extern "js" fn install(
  reset : (Int32, Double) -> Unit,
  step : () -> Unit,
  snapshot : () -> String,
  drag : (Int32, Double, Double) -> Unit,
  error : () -> String,
) -> Unit =
  #| (reset, step, snapshot, drag, error) => {
  #|   globalThis.moonDeform = {reset, step, snapshot, drag, error};
  #|   globalThis.dispatchEvent(new Event('moonDeformReady'));
  #| }

///|
fn scene(
  kind : Int32,
  softness : Double,
) -> (@deform.World, Array[@deform.Body]) raise @deform.PhysicsError {
  let w = @deform.World::new()
  w.add_plane(@deform.Vec2::new(0.0, 1.0), 0.0)
  w.add_plane(@deform.Vec2::new(1.0, 0.0), -4.8)
  w.add_plane(@deform.Vec2::new(-1.0, 0.0), -4.8)
  w.add_circle(@deform.Vec2::new(0.0, 1.3), 0.55)
  let bodies = match kind {
    0 =>
      [
        w.rope(
          @deform.Vec2::new(-2.4, 4.8),
          @deform.Vec2::new(1.8, 4.8),
          24,
          compliance=softness,
        ),
      ]
    1 =>
      [
        w.grid(
          @deform.Vec2::new(-1.5, 4.5),
          11,
          9,
          0.3,
          compliance=softness,
          area_compliance=softness * 0.1,
        ),
      ]
    _ =>
      [
        w.soft_ring(
          @deform.Vec2::new(-0.4, 4.2),
          0.9,
          24,
          compliance=softness,
          area_compliance=softness * 0.01,
        ),
      ]
  }
  (w, bodies)
}

///|
fn main raise {
  let (initial_world, initial_bodies) = scene(2, 0.0001)
  let world = Ref(initial_world)
  let bodies = Ref(initial_bodies)
  let error = Ref("")
  install(
    fn(kind, softness) {
      try {
        let (w, b) = scene(kind, softness)
        world.val = w
        bodies.val = b
        error.val = ""
      } catch {
        e => error.val = e.message()
      }
    },
    fn() {
      ignore(world.val.step(1.0 / 60.0)) catch {
        e => error.val = e.message()
      }
    },
    fn() {
      try {
        let w = world.val
        let report = w.report()
        let points = w.positions().map(fn(p) { "[\{p.x},\{p.y}]" })
        let edges : Array[String] = []
        for body in bodies.val {
          for edge in body.edges {
            edges.push("[\{edge.0},\{edge.1}]")
          }
        }
        "{\"points\":[" +
        points.join(",") +
        "],\"edges\":[" +
        edges.join(",") +
        "],\"time\":\{report.time},\"residual\":\{report.max_constraint_error},\"energy\":\{report.kinetic_energy}}"
      } catch {
        e => {
          error.val = e.message()
          "{}"
        }
      }
    },
    fn(id, x, y) {
      world.val.set_position(id, @deform.Vec2::new(x, y)) catch {
        e => error.val = e.message()
      }
    },
    fn() { error.val },
  )
}
