# Depth-ordered completion caps

Completed-vial caps no longer live in one SwiftUI overlay above the entire board. That overlay made a rear cap paint over a moving foreground vial, most visibly in the earlier Classic portrait capture.

Classic and 2D Fluid now draw each cap inside the same per-vial layer as its glass. Moving vials retain their existing foreground layer, so they naturally cover a rear completed cap. The 3D renderer now draws an opaque stopper mesh with the vial transform inside the multisampled glass pass. It shares the glass depth buffer, so actual scene depth decides whether the cap or a crossing vial is visible. Selected vials and active pour sources/destinations remain uncapped.

The cap keeps the matched liquid color, metallic highlight and grip grooves. Completed-vial detection is now shared by the board state instead of being duplicated in the session and renderers.

## Regression coverage

The overlap suite adds a completed blue vial with a source crossing its cap. Six fixtures now run in Classic, 2D Fluid and 3D Fluid. All 36 transfers completed. Sampled 3D paths reported no physical intersections, and 2D/3D reported no clipping in portrait or landscape at the checked camera angles. [Summary](overlap-summary.json).

The native captures show the crossing in [Classic](classic-cap-crossing-portrait.png), [2D Fluid](fluid2D-cap-crossing-portrait.png) and [3D Fluid](fluid-cap-crossing-portrait.png). These renderer captures exercise deterministic paths; they are not finger-driven UI automation.

The macOS Release build and signed iOS Release build pass. The existing [reset-all-progress regression](reset-validation.log) also passes in all three presentations after the shared completion predicate change: active-pour reset, all 12 initial puzzles, undo isolation, relaunch persistence, bundled Original-game stores and retained preferences.

## iPad validation

The signed build was installed on the connected M4 iPad Pro. A portrait Green arrival Classic run reproduced the original overlap geometry. In the [device capture](ipad-classic-cap-crossing.png), the mixed-color moving source correctly covers most of the rear blue stopper instead of the stopper floating over it.

The Classic trial completed 14/14 transfers in 33.872 seconds. The 3D trial completed 10/10 in 23.096 seconds with 1.094% maximum cleanup. Both reached two concurrent pours and two sources sharing a receiver, ended normally and remained thermally nominal. These runs used screen capture and USB/full battery, so their timings are functional evidence, not clean frame-rate or energy measurements. See the [Classic](ipad-classic-trial.json) and [3D](ipad-3d-trial.json) reports.

The new Metal caps are visible and aligned in actual-device [portrait](ipad-3d-portrait.png) and [landscape](ipad-3d-landscape.png) captures. The iPad was returned to landscape-left. The earlier reset confirmation was verified through Mac accessibility automation and state regressions; this session did not add touch-driven iPad automation for that confirmation sheet.

The inherited Original-game solver correction and measured 3D frame-pacing work remain separate follow-ups.
