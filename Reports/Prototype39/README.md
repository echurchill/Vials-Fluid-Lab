# Prototype 39 — vessel silhouettes describe their roles

September 21, 2026. Local changes; not committed or pushed.

## Assignment

- Ordinary sources, storage and final targets: traditional test tube.
- Mixer and Recovery/separator inputs and outputs: round bulb flask.
- Density-changing chambers: flat-bottomed tapered flask.
- Pear flask: retained as an explicit shape, reserved for future labs.

Final targets take priority over machine roles. For a shared non-target chamber, density takes priority over mixer/separator. Shared tool badges remain visible. Shapes derive from fixed level metadata and stay fixed through pours, transformations and completion. Sorting and Discovery therefore use tubes throughout.

Classic, 2D, 3D, and hit/highlight geometry use the same state-aware profile factory. The 3D mesh/particle seed cache now checks shapes as well as capacities, preventing stale geometry when switching between boards with equal capacities and different tools.

## Geometry guardrails

The four existing profile knot arrays are unchanged. Height remains `2.35 * sqrt(capacity / 4)`, depth scale stays 1, and the existing radial volume normalization remains in place. Camera and board layout formulas are unchanged. This intentionally changes which silhouette each vial uses, not the accepted capacity/size policy. A machine output that is also a final target remains a tube throughout the level.

## Validation

- Mac Release and signed iOS Release builds passed.
- Role assignments checked for all 39 boards, precedence, fixed shapes through authored routes, four silhouettes at capacities 1–6, proportional volume, cross-renderer profile parity, and same-capacity cache invalidation.
- Presentation harness passed complete small-capacity routes for Measured batch, Heavy landing, Second chance and Twin products in Classic/2D/3D, with portrait/landscape captures and fill-height checks. Five streams static captures also generated.
- All 18 lab/presentation concurrency cases plus density arrival order, Discovery reveals, machine guards and control checks passed.
- All 69 animated machine cases passed.
- Existing Sorting concurrent-pour regressions, including Valve circuit partial returns and shared receivers, passed.
- Density trajectory, stable-tie, volume, pause and completion regressions passed.
- Physical iPad: updated build installed; Twin products visually inspected through QuickTime in Classic, 2D and 3D. Sources/targets are tubes, mixers rounded, density chambers tapered; labels and controls fit in landscape.
- Selected offscreen Recovery and portrait Crossover captures inspected. These are renderer checks, not a physical-iPad portrait or touch-latency test.

Caffeinate was active during Mac UI checks. Scheduled performance monitoring remains paused. Sound remains deferred. Earlier Prototype37/38 changes and the unrelated root PNG are preserved.

## Physical-iPad trials on this build

- 2D: 12/12 pours committed; max cleanup 0.00%; two concurrent/shared-receiver pours; all seven control checks passed. Report timestamp 2026-09-21T18:25:20Z.
- 3D: 10/10 pours committed; max cleanup 2.03%; two concurrent/shared-receiver pours; all seven control checks passed. Report timestamp 2026-09-21T18:24:12Z.

Both short plugged-in trials remained thermally nominal. These are correctness/control checks, not battery-life or compositor-FPS measurements. The first 2D attempt was restarted before its report completed; only the completed rerun is retained. iPad returned to normal play after trials.
