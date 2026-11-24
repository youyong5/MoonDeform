///|
/// A value type; reading positions never exposes mutable solver storage.
#derive(Eq, @debug.Debug)
pub(all) struct Vec2 {
  x : Double
  y : Double
}

///|
pub extend Vec2 with Eq::{equal, not_equal}

///|
pub extend Vec2 with @debug.Debug::{to_repr}

///|
pub fn Vec2::new(x : Double, y : Double) -> Vec2 {
  { x, y, }
}

///|
pub fn Vec2::add(self : Vec2, other : Vec2) -> Vec2 {
  { x: self.x + other.x, y: self.y + other.y, }
}

///|
pub fn Vec2::sub(self : Vec2, other : Vec2) -> Vec2 {
  { x: self.x - other.x, y: self.y - other.y, }
}

///|
pub fn Vec2::scale(self : Vec2, k : Double) -> Vec2 {
  { x: self.x * k, y: self.y * k, }
}

///|
pub fn Vec2::dot(self : Vec2, other : Vec2) -> Double {
  self.x * other.x + self.y * other.y
}

///|
pub fn Vec2::length(self : Vec2) -> Double {
  let scale = self.x.abs().max(self.y.abs())
  if scale == 0.0 {
    return 0.0
  }
  if !finite(scale) {
    return scale
  }
  let x = self.x / scale
  let y = self.y / scale
  scale * (x * x + y * y).sqrt()
}

///|
fn finite(x : Double) -> Bool {
  !x.is_nan() && !x.is_inf()
}

///|
fn finite_vec(v : Vec2) -> Bool {
  finite(v.x) && finite(v.y)
}

///|
fn cross(a : Vec2, b : Vec2) -> Double {
  a.x * b.y - a.y * b.x
}

///|
/// Signed area, positive for counterclockwise vertices in Cartesian coordinates.
pub fn signed_area(points : Array[Vec2]) -> Double {
  if points.length() < 3 {
    return 0.0
  }
  // Translate to a local origin before multiplying coordinates. This avoids
  // subtracting nearly equal world-coordinate products for distant models.
  let origin = points[0]
  let mut a = 0.0
  for i in 1..<(points.length() - 1) {
    a += cross(points[i].sub(origin), points[i + 1].sub(origin)) * 0.5
  }
  a
}

///|
fn wrap_angle(a : Double) -> Double {
  let pi = 3.141592653589793
  if a > pi {
    a - 2.0 * pi
  } else if a < -pi {
    a + 2.0 * pi
  } else {
    a
  }
}
