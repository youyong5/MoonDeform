///|
test "area and bend analytical gradients agree with central differences" {
  let p = [Vec2::new(0.3, 0.2), Vec2::new(1.8, 0.4), Vec2::new(0.7, 1.9)]
  let kinds : Array[ConstraintKind] = [Area(0.6), Bend(0.3), Distance(1.0)]
  for kind in kinds {
    let points = match kind {
      Distance(_) => [p[0], p[1]]
      _ => p.copy()
    }
    let (_, grad) = constraint_value(kind, points)
    for i in 0..<points.length() {
      for axis in 0..<2 {
        let h = 0.000001
        let delta = if axis == 0 {
          Vec2::new(h, 0.0)
        } else {
          Vec2::new(0.0, h)
        }
        let plus = points.copy()
        let minus = points.copy()
        plus[i] = plus[i].add(delta)
        minus[i] = minus[i].sub(delta)
        let (v1, _) = constraint_value(kind, plus)
        let (v0, _) = constraint_value(kind, minus)
        let numeric = (v1 - v0) / (2.0 * h)
        let analytic = if axis == 0 { grad[i].x } else { grad[i].y }
        assert_true((numeric - analytic).abs() < 0.000001)
      }
    }
  }
}
