# Prototype 05 — a playable progression

September 8, 2026. Native Swift + Metal; no Unity.

## Play

The board now has a 12-puzzle progression. The first three retain the two-color introduction; the next nine use six vials and three colors: Tide blue, Ember orange and Leaf green. All levels are available from the puzzle menu. Completed boards receive a checkmark, and a solved puzzle offers a Next button. The same puzzle state, hints, undo and saved progress work in Classic and Fluid.

Use the top-right Board options menu for optional pouring sound, haptics where hardware supports them, and Fluid detail. Sound starts disabled. The quiet procedural water loop follows the stream and stops on pause, reset, completion or suspension. Haptics provide light selection/landing feedback on supported devices; an iPad without a haptic actuator will not produce a vibration.

Fluid detail offers Automatic, High and Low energy. High caps the longest rendering dimension at 1000 pixels; Low energy uses 720. Automatic uses 1000 under normal conditions and 720 when Low Power Mode or elevated thermal state is reported. These controls change image resolution, not the particle count, rules, timestep or pour speed. Sound/detail preferences are saved separately, so existing Prototype 04 puzzle saves remain compatible.

## Implementation

- Vial count drives positions, profiles, meshes, hit regions, Classic layout, layer constraints and shader vessel counts. This release ships four- and six-vial boards, four-unit capacity and up to three colors; it does not claim arbitrary board size/capacity support.
- Palette filtering now smooths RGB surface colors rather than numerical color IDs, avoiding an orange band invented between blue and green.
- Larger liquid splats reduce gaps and scallops; the remaining surface is still an approximate particle reconstruction.
- Vial tilt accelerates gradually at the start. Extra viscosity during the return helps residual motion settle. Lift/travel/return retain smooth easing.
- Glass uses 48 rings × 64 segments, down from 96 × 96, to offset the cost of additional vials. Original pour-study meshes retain their defaults.
- The receiver's invisible guide has a wider apron and a short throat following the inner rim. It guides only eligible airborne pour particles near the receiving opening. It cannot reclaim droplets on the tray. The final cleanup ceiling remains 5%; the cutoff uses that same allowance.
- The funnel enable flag has its own shader bit, separate from the fifth/sixth vial activation bits. Inactive vials must remain stationary during a different pair's pour.
- Hint search recognizes equivalent vial permutations, while preserving the actual move route and unit IDs. Every authored level is checked for a legal solution.

## Validation

Run `bash Scripts/validate_progression.sh` for all new Fluid solutions, mixed Classic/Fluid play across old and larger puzzles, saved progress/undo, sound decoding, and a portrait case. `--expanded` on the comparison validator checks every level in both paces. The retained pour-study shader is checked separately with its water regression fixture.

All 162 progression/comparison transfers passed: 85 new-level Fluid transfers, 62 mixed-presentation transfers, six original-board Relaxed transfers and nine portrait transfers at 30 Hz. The retained water pour-study regression also passed. New-level Quick turns took 3.92–5.27 seconds; the largest cleanup across the final board fixtures was 0.625%. No sampled glass intersections or inactive-vial movement were detected. Exact inventory, color ownership, undo, pause, saved progress and Next-level transitions passed; the optional two-second audio loop decoded successfully.

The matched offscreen rendering-budget check repeated Green arrival at 1000×650 and 720×468 pixels. The median of per-move GPU medians was 5.62 ms at High and 5.34 ms at Low energy, about a 5% decrease. Both nine-move runs passed. This is a modest GPU-time saving, not a measurement of battery savings.

See [measurement details](Measurements.md), [Fluid portrait](fluid-six-portrait.png), [Classic portrait](classic-six-portrait.png), and [the six-vial board](fluid-six.png). Measurements and captures beside this document record the final checks. Offscreen fixture times describe the simulation clock; only device trials measure sustained on-device behavior. Failed tuning candidates are excluded from final evidence.

## Battery trial protocol

The iPad runs Green arrival / Quick for ten minutes in Classic, then ten minutes in Fluid, unplugged over the local network. Trial launch arguments are:

```
--lab-trial --presentation classic --pace quick --puzzle greenArrival --seconds 600 --keep-awake
--lab-trial --presentation fluid --pace quick --puzzle greenArrival --seconds 600 --keep-awake
```

`--quality high` or `--quality lowEnergy` can select a fixed render budget. A trial leaves saved player progress untouched and records local JSON in Documents/FluidLabReports. `--keep-awake` is confined to the timed test and restores the prior idle-timer behavior when it finishes; it does not unlock a locked device or change system lock settings. Normal play keeps the device's normal sleep behavior. Relaunch without trial arguments after testing.

Battery percentages are coarse, particularly near 100%. Report start/end readings, duration and thermal state without extrapolating short runs to hours of battery life. Different start percentages and fixed run order limit direct energy comparisons. A useful follow-up is to repeat in reverse order after the battery is below full and the device has cooled. This prototype uses assisted layers; it does not yet implement density sorting or chemical/color mixing.
