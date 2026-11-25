///|
extern "js" fn install(
  reset : (Int32, Double) -> Unit,
  step : () -> Unit,
  snapshot : () -> String,
  drag : (Int32, Double, Double) -> Unit,
  tune : (Double) -> Unit,
  error : () -> String,
) -> Unit =
  #| (reset, step, snapshot, drag, tune, error) => {
  #|   globalThis.moonDeform = {reset, step, snapshot, drag, tune, error};
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
  let scene_kind = Ref(2)
  let error = Ref("")
  install(
    fn(kind, softness) {
      try {
        let (w, b) = scene(kind, softness)
        world.val = w
        bodies.val = b
        scene_kind.val = kind
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
        let mut distance_compliance = "null"
        let mut area_compliance = "null"
        let mut bend_compliance = "null"
        let mut stretch_error = 0.0
        for body in bodies.val {
          for edge in body.edges {
            edges.push("[\{edge.0},\{edge.1}]")
          }
          for id in body.constraints {
            let info = w.constraint_info(id)
            match info.kind {
              Distance => {
                distance_compliance = "\{info.compliance}"
                if info.enabled {
                  match w.constraint_residual(id) {
                    Some(value) =>
                      stretch_error = stretch_error.max(value.abs())
                    None => ()
                  }
                }
              }
              Area => area_compliance = "\{info.compliance}"
              Bend => bend_compliance = "\{info.compliance}"
              Custom => ()
            }
          }
        }
        "{\"points\":[" +
        points.join(",") +
        "],\"edges\":[" +
        edges.join(",") +
        "],\"time\":\{report.time},\"residual\":\{report.max_constraint_error},\"energy\":\{report.kinetic_energy},\"stretch_error\":\{stretch_error},\"material\":{\"distance\":\{distance_compliance},\"area\":\{area_compliance},\"bend\":\{bend_compliance}}}"
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
    fn(softness) {
      if softness < 0.0 || softness.is_nan() || softness.is_inf() {
        error.val = "Invalid input: softness must be finite and nonnegative"
        return
      }
      try {
        let w = world.val
        for body in bodies.val {
          for id in body.constraints {
            let info = w.constraint_info(id)
            match info.kind {
              Distance => w.set_constraint_compliance(id, softness)
              Area =>
                w.set_constraint_compliance(
                  id,
                  softness * (if scene_kind.val == 1 { 0.1 } else { 0.01 }),
                )
              // Angular and user-defined materials keep their own units.
              Bend | Custom => ()
            }
          }
        }
        error.val = ""
      } catch {
        e => error.val = e.message()
      }
    },
    fn() { error.val },
  )
}
