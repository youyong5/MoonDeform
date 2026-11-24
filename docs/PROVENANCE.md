# Provenance and third-party notices

## Pinned source

- Repository: https://github.com/InteractiveComputerGraphics/PositionBasedDynamics
- Commit: `10a70bc146a97873dc3c8fef372f5217e010542e`
- License: MIT; copyright (c) 2015-present, PositionBasedDynamics contributors.
- Stored verbatim: `PositionBasedDynamics/XPBD.cpp`, `PositionBasedDynamics/XPBD.h`, and `LICENSE`, under `third_party/PositionBasedDynamics/`.
- SHA-256 of stored XPBD.cpp: `49c24c796f9dae7d0565e930ada920b9b86d92a8b54a0da6ddafe18790ad03ab`.

`constraints.mbt` ports the upstream distance projection to MoonBit/2D and accepts compliance directly. The generic scalar projection is organized so that built-in area/bend constraints and consumer-supplied constraints share the same update rule. These are adaptations and engineering extensions, not a new physical algorithm.

Deliberate differences: near-coincident distance endpoints use a deterministic x axis rather than the upstream no-op; denominator tolerances differ; public inputs and numerical failures are validated. The 40-case C++ differential fixture covers nondegenerate distance projections only and does not establish equivalence for all constraints or trajectories.

The GitHub-preparation review adds scaled vector norms and local-origin signed-area evaluation to reduce avoidable overflow, underflow and translation cancellation. These are numerical implementation improvements, not new XPBD equations.

`scripts/upstream_reference.py` extracts the verbatim distance function from the pinned source, supplies a minimal double-precision vector shim, and runs 40 configurations. It does not compile the complete upstream project. The fixture is checked into `upstream_distance_wbtest.mbt` and compared by MoonBit tests.

## Research reference

Miles Macklin, Matthias Müller, Nuttapong Chentanez. “XPBD: Position-Based Simulation of Compliant Constrained Dynamics,” Motion in Games, 2016. https://mmacklin.com/xpbd.pdf

## AI-assisted development

AI assisted repository comparison, translation, interface design, tests, demonstration code, documentation and debugging. The pinned source, license and reference procedure are recorded so that implementation claims can be independently checked. The implementation has not undergone an independent human numerical-methods audit.

No code or assets were copied from the other candidates listed in UPSTREAM.md.
