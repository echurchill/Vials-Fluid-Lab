# Smoother pour setup and separated 3D travel

## Changes

Receiver-group preparation now reuses canonical particle positions for each vessel and unit slot. These positions depend on shape, not the current puzzle colors or parcel identities. Changing the number of profiles invalidates the cache. Both receiver slots inherit the prepared profile cache before play, so their first pour does not rebuild it. The existing exact logical reservations and 5% maximum cleanup allowance are unchanged.

The 3D solver skips position-correction calculations for frozen particles, whose corrections are never consumed. It retains their pressure calculation and neighbor-grid presence, preserving their contribution to any active neighbors. This is a targeted removal of unused work, not a reduction in particle count or solver iterations.

Each active 3D source receives a stable front/back travel lane. The lane persists through lift, travel, pouring and return, including when a second source joins late. The particle grid and front world boundary now include both routes. Classic and 2D retain stable whole-vial drawing order and their existing smoked/lens treatments.

Planar layouts and the 3D camera reserve fixed room for outward pours at edge receivers. This makes the resting board somewhat smaller, but avoids both clipping and zooming/fill-level shifts when a pour begins. Hit regions, caps and hints use those same layout/camera helpers.

## Verified on the Mac

The [baseline path probe](paths-before.json) found physical intersections on crossing and late-join paths. The updated [path probe](paths.json) checks four- and six-vial boards, both lane assignments, four delays and four route fixtures (64 combinations). Its sampled outer surfaces remain separate, and stay inside portrait/landscape framing at three camera angles. Sampling is not a mathematical proof for every possible continuous path.

The [running-fluid overlap checks](overlap-summary.json) complete both transfers in every fixture: crossing routes, late shared-left joins, simultaneous shared-right joins, return crossings and near-full shared receivers, in all three presentations (30 transfers). The 3D checks report no sampled intersections; 2D and 3D checks report no clipping. Classic is inspected through native captures; its zero placeholder clipping counters are not a quantitative Classic geometry test.

Native captures show [Classic crossings](classic-crossing-65-landscape.png), [2D edge pours](fluid2D-shared-right-140-landscape.png), [3D late joins](fluid-shared-left-140-landscape.png) and [3D portrait edge pours](fluid-shared-right-140-portrait.png). These are board-renderer captures, not touch-driven automation of the complete app UI.

The new routes initially exposed a near-full capture failure: a one-unit transfer could miss the 95% threshold while the larger transfer completed. Most missed droplets had never entered the guide. Moving the mouths closer made this worse and was discarded. The final change retains their original separation and lowers the mouths into guide range earlier in the tilt. The cleanup allowance and guide dimensions remain unchanged. [Initial failure evidence](near-full-before.log).

The final motion passes [12 repeated three-plus-one trials](near-full-stress.log) and [12 more in a fresh process](near-full-stress-repeat.log): 48 transfers without a rejection. The [full concurrency regression](concurrent.log) passes, including partial capacity, late shared receivers, pause/background handling, checkpointing, undo, reset and the worker cancellation race. [Two full 3D puzzle solutions](autoplay-3d.log) also pass with particle-inventory and ownership checks.

## Performance evidence and limits

The [alternating setup benchmark](seed-setup.json) runs old and cached receiver-group preparation in the same process, reversing order each iteration. It verifies exact particle values, including after four/six-profile changes. After warmup, across 60 samples per version, median setup falls from 3.638 ms to 0.225 ms; p95 falls from 3.955 ms to 0.318 ms. These numbers cover group preparation only, not complete animation frames.

Before the travel/framing changes, the [whole-puzzle offscreen comparisons](mac-benchmark-comparisons.json) separate controller/solver waits from surface GPU work. All completed two Green arrival solutions with no rejected transfer. Timing varied between runs; some overall p95/max values were worse after the change. They do not establish an overall frame-rate or hitch-rate improvement. The repeated shader-optimized runs show lower median turn-start cost, but the paired setup benchmark is the stronger evidence for the cache change. These measurements do not establish the final build’s displayed-frame performance.

Mac Instruments failed to finalize usable Game Performance traces both when launching and when attaching; export reported “Document Missing Template Error.” Those captures are rejected. `caffeinate -di` was active throughout testing. Displayed-frame timing therefore remains unverified for this build.

The final macOS and signed iOS Release builds pass. No iPad operation or installation was performed during this work. The user is testing the prior stuck-pour fix and has reserved the device until later. Next device checks: verify the new motion/framing by touch, then collect a separate USB display/GPU profile. Keep an unplugged sustained-play check separate; neither offscreen Mac timing nor charging measurements establish battery life.

## Reproduction

Use a built macOS Metal library:

```sh
bash Scripts/validate_overlap.sh path/to/default.metallib build/overlap-checks
bash Scripts/benchmark_concurrent_3d.sh path/to/default.metallib build/concurrent-benchmark
bash Scripts/benchmark_seed_setup.sh path/to/default.metallib build/seed-setup
xcrun swiftc -O -parse-as-library Vials/FluidLab/LabGeometry.swift Vials/FluidLab/LabBoard.swift Vials/FluidLab/LabBoardGeometry.swift Scripts/validate_pour_paths.swift -o build/pour-paths
build/pour-paths build/paths.json
```

Avoid concurrent builds, profiler sessions or other benchmarks during performance measurements. Raw trace attempts and full per-frame samples stay in the ignored external-drive `build/overlap-performance` directory.
