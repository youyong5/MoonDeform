// Exercise the compiled browser bridge with the real MoonBit solver, under Node.
// This does not test browser layout, pointer dispatch, or Canvas rendering.
const assert = require('node:assert/strict');
const {performance} = require('node:perf_hooks');
const path = require('node:path');
globalThis.dispatchEvent = () => true;
require(path.resolve(__dirname, '../dist/solver.js'));
const api = globalThis.moonDeform;
assert.ok(api);
const results = [];
for (const kind of [0, 1, 2]) {
  api.reset(kind, 1e-4);
  let state = JSON.parse(api.snapshot());
  const start = performance.now();
  for (let i = 0; i < 360; i++) api.step();
  const ms = performance.now() - start;
  state = JSON.parse(api.snapshot());
  assert.equal(api.error(), '');
  assert.ok(Math.abs(state.time - 6) < 1e-9);
  assert.ok(state.points.every(p => p.every(Number.isFinite)));
  assert.ok(state.points.every(p => p[1] >= 0.019999));
  const movable = kind === 0 ? state.points.length - 1 : 5;
  api.drag(movable, 0.3, 4.0);
  state = JSON.parse(api.snapshot());
  assert.deepEqual(state.points[movable], [0.3, 4]);
  const beforeTune = state;
  api.tune(3e-4);
  state = JSON.parse(api.snapshot());
  assert.equal(api.error(), '');
  assert.deepEqual(state.points, beforeTune.points);
  assert.deepEqual(state.edges, beforeTune.edges);
  assert.equal(state.time, beforeTune.time);
  assert.equal(state.energy, beforeTune.energy);
  assert.equal(state.stretch_error, beforeTune.stretch_error);
  assert.equal(state.material.distance, 3e-4);
  assert.equal(state.material.area, kind === 0 ? null : 3e-4 * (kind === 1 ? .1 : .01));
  assert.equal(state.material.bend, beforeTune.material.bend);
  for (const invalid of [-1, NaN, Infinity]) {
    api.tune(invalid);
    assert.match(api.error(), /finite and nonnegative/);
    assert.deepEqual(JSON.parse(api.snapshot()), state);
  }
  api.tune(0);
  assert.equal(api.error(), '');
  api.step();
  state = JSON.parse(api.snapshot());
  assert.equal(api.error(), '');
  assert.ok(state.time > beforeTune.time);
  assert.ok(Number.isFinite(state.stretch_error));
  assert.ok(state.points.every(p => p.every(Number.isFinite)));
  results.push({kind, particles:state.points.length, steps:360, milliseconds:Number(ms.toFixed(2))});
}
api.reset(2, -1);
assert.match(api.error(), /nonnegative/);
api.reset(2, 1e-4);
assert.equal(api.error(), '');
console.log(JSON.stringify({runtime:process.version,results},null,2));
