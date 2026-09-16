# Shared receivers and clearer overlapping vials

Two compatible sources can now pour into one receiver at the same time in Classic, 2D Fluid and 3D Fluid. Each accepted pour keeps its exact reserved amount, including when the second source can supply only the remaining capacity. Two active pours remain the global limit. Source vials remain exclusive until their animation finishes.

Each receiver has one simulation containing both incoming streams. Sources approach from opposite, stable slots. Individual completion corrects only that transfer’s missing particles within the existing 5% allowance. Pause, background suspension, reset, saved progress and undo retain the prior behavior.

Classic uses a darker foreground cavity and more opaque liquid. 2D draws complete vial layers in depth order and lightly distorts the rear image through a moving foreground vessel; the lens is disabled for Reduce Transparency, Low Power Mode, thermal pressure and particle diagnostics. 3D composites glass from back to front, allowing the front shell to refract rear glass details as well as liquid. This remains a screen-space approximation, not full optical ray tracing.

## Stalled-pour investigation

The first iPad trial exposed a real stale-particle bug: when a source finished a transfer and quickly joined another receiver group, the new group could retain old liquid that had already left that source. That phantom inventory could obstruct its mouth. Both fluid engines now refresh particles outside their active ownership from the current committed board, and the 3D compositor releases finished source ownership promptly.

The screenshot marked “Paused / Measurement saved” also exposed a diagnostic shutdown problem. The timed trial used to pause immediately, even halfway through a pour. It now stops scheduling new moves, lets active transfers finish, then pauses. If the app is suspended or the drain deadline expires, the diagnostic restores the committed board instead of leaving airborne sources frozen.

Additional 3D autoplay exposed the old horizontal physics boundary clipping sources assigned to the outside approach of an edge receiver. The world boundary and particle neighbor grid now include that approach space.

## Validation

The direct 2D worker solved [all 12 authored puzzles](planar-puzzles.json) (125 transfers), with no rejected transfer and particle inventory checks on every frame. Two repeated Green arrival solutions also pass the session-level autoplay check.

The [concurrency regression](concurrent.log) passes in all three views: actual simultaneous streams, late same-side joins, partial capacity, reverse completion, pause/suspension, queue limits, checkpointing, undo and reset. Both [2D](autoplay-2d.log) and [3D](autoplay-3d.log) complete two repeated Green arrival solutions. The final 3D run also checks particle inventory, finite positions and inactive parcel ownership each frame.

Native captures: [Classic](classic-shared.png), [2D Fluid](fluid2D-shared.png), [3D Fluid](fluid-shared.png). These show actual simultaneous streams. Opposite approach slots separate the mouths; this is not a general collision-free path planner for every possible pair of moving vessels.

Existing comparison and session regressions pass: exact replay across presentations, saved-game isolation, pause/background/reset/undo, immutable worker snapshots, fallback behavior and presentation switching. Native offscreen captures validate rendering; these are not touch-driven UI automation. Mac checks use `caffeinate -di`.

## iPad

The initial [interrupted report](ipad-2d-before-fix.json) is retained as failure evidence, not a passing benchmark. The corrected [2D report](ipad-2d.json) completed 59 of 59 pours in 122.883 seconds, including a 2.798-second drain after the requested 120 seconds. It reached two simultaneous pours into one receiver. Pause, suspension, resume, reset, commit, undo and save/reload checks all passed.

2D controller intervals: median 17.769 ms, p95 17.934 ms, maximum 21.100 ms. Worker solver time: median 4.463 ms, p95 6.745 ms, maximum 7.536 ms. The iPad remained thermally nominal. Controller intervals are not compositor FPS; worker timing excludes Canvas drawing. Wired USB and full battery mean this run does not measure battery drain.

The [3D report](ipad-3d.json) completed 50 of 50 pours in 123.565 seconds, including a 3.564-second drain. Two sources shared a receiver; all seven device control checks passed. Maximum correction was 0.573%, below the 5% limit. Controller intervals: median 17.815 ms, p95 20.016 ms, maximum 63.267 ms; 166 of 6,761 intervals exceeded 25 ms. Combined reported GPU work: median 9.225 ms, p95 15.181 ms. These counters include scheduling/waits and are not a display profiler. Thermal state remained nominal. The occasional 3D timing spikes remain a performance follow-up.

The device trials include the stale-inventory, edge-boundary and diagnostic-drain fixes. The final app additionally measures wrong-owner/outside/nonfinite counters for active 3D groups; the expanded Mac regression validates those checks.

## Reproduce

```sh
bash Scripts/validate_concurrent.sh path/to/default.metallib build/shared
build/shared/validate build/shared/default.metallib build/shared --autoplay fluid2D
build/shared/validate build/shared/default.metallib build/shared --autoplay fluid
xcrun swiftc -O -parse-as-library Vials/FluidLab/LabGeometry.swift Vials/FluidLab/LabBoard.swift Vials/FluidLab/LabBoardGeometry.swift Vials/FluidLab/LabBoardPreferences.swift Vials/FluidLab/LabFluid2D.swift Scripts/validate_shared_solver.swift -o build/shared/solver
build/shared/solver greenArrival
```

Pass a different `LabBoardPuzzle` raw value to the direct solver check to reproduce another puzzle.

macOS and signed iOS Release builds pass. The normal iPad app was installed and launched with saved progress preserved; the disposable trial app was removed. No touch-driven UI automation or battery-life claim is made.
