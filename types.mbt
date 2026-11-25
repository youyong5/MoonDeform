///|
pub suberror PhysicsError {
  InvalidInput(String)
  InvalidHandle(Int32)
  NumericalFailure(String)
}

///|
pub fn PhysicsError::message(self : PhysicsError) -> String {
  match self {
    InvalidInput(message) => "Invalid input: " + message
    InvalidHandle(id) => "Invalid handle: \{id}"
    NumericalFailure(message) => "Numerical failure: " + message
  }
}

///|
/// Solver configuration. Construction is validated by World::new.
pub(all) struct Config {
  gravity : Vec2
  substeps : Int32
  iterations : Int32
  damping : Double
  restitution : Double
  friction : Double
}

///|
pub fn Config::new(
  gravity~ : Vec2 = Vec2::new(0.0, -9.81),
  substeps~ : Int32 = 4,
  iterations~ : Int32 = 8,
  damping~ : Double = 0.2,
  restitution~ : Double = 0.0,
  friction~ : Double = 0.2,
) -> Config {
  { gravity, substeps, iterations, damping, restitution, friction, }
}

///|
priv struct Particle {
  mut position : Vec2
  mut velocity : Vec2
  mut force : Vec2
  inv_mass : Double
  radius : Double
}

///|
/// C(x), gradients dC/dx in the same order as the supplied particle handles.
/// Implementations must be pure, return finite values, and preserve arity.
pub type ConstraintFunction = (Array[Vec2]) -> (Double, Array[Vec2])

///|
/// Public categories for host material controls and unit-aware diagnostics.
#derive(Eq, @debug.Debug)
pub(all) enum ConstraintType {
  Distance
  Area
  Bend
  Custom
}

///|
pub extend ConstraintType with Eq::{equal, not_equal}

///|
pub extend ConstraintType with @debug.Debug::{to_repr}

///|
/// A detached metadata snapshot. Particle handles belong to the source world.
#derive(Eq, @debug.Debug)
pub(all) struct ConstraintInfo {
  kind : ConstraintType
  particles : Array[Int32]
  compliance : Double
  enabled : Bool
}

///|
pub extend ConstraintInfo with Eq::{equal, not_equal}

///|
pub extend ConstraintInfo with @debug.Debug::{to_repr}

///|
priv enum ConstraintKind {
  Distance(Double)
  Area(Double)
  Bend(Double)
  Custom(ConstraintFunction)
}

///|
priv struct Constraint {
  ids : Array[Int32]
  kind : ConstraintKind
  mut compliance : Double
  mut multiplier : Double
  mut enabled : Bool
}

///|
priv enum Collider {
  Plane(Vec2, Double)
  Circle(Vec2, Double)
}

///|
/// Handles are stable integer indices, scoped to the world that allocated them.
/// Constraints can be disabled without invalidating other handles.
pub struct World {
  priv config : Config
  priv particles : Array[Particle]
  priv constraints : Array[Constraint]
  priv colliders : Array[Collider]
  priv mut elapsed : Double
  priv mut busy : Bool
}

///|
pub(all) struct StepReport {
  time : Double
  max_constraint_error : Double
  kinetic_energy : Double
  max_speed : Double
  particle_count : Int32
  constraint_count : Int32
}

///|
/// A topology description for host renderers; the library owns no drawing APIs.
pub(all) struct Body {
  particles : Array[Int32]
  constraints : Array[Int32]
  edges : Array[(Int32, Int32)]
}
