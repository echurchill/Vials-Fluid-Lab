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

The final macOS and signed iOS Release builds pass. Build `70d8f8b` was installed on the M4 iPad Pro on September 16. The user authorized resetting development sessions as needed, so these checks used the normal development app directly.

## iPad validation

Two clean 120-second Quick / Green arrival trials ran without Instruments, screen recording or screenshot capture. Both exercised two concurrent sources and two sources sharing one receiver. Every pause, suspension, resume, reset, commit, undo and save/reload check passed. Both reports ended normally and drained the final pours before stopping.

| Check | 3D Fluid | 2D Fluid |
| --- | ---: | ---: |
| Successful / attempted transfers | 48 / 48 | 59 / 59 |
| Actual duration including drain | 121.565 s | 122.603 s |
| Largest cleanup | 0.781% | 1.042% |
| Controller interval median / p95 | 17.827 / 22.333 ms | 17.769 / 17.935 ms |
| Maximum controller interval | 79.369 ms | 20.607 ms |
| Controller intervals over 25 ms | 186 / 6,561 | 0 / 6,828 |
| Thermal state throughout | Nominal | Nominal |

[3D report](ipad-3d.json), [2D report](ipad-2d.json). These are controller timings, not displayed frames. The prior Prototype18 3D run had a 20.016 ms p95 and 63.267 ms maximum, so this sample does **not** establish smoother overall playback. It completed 48 pours versus the prior run's 50; differing physical routes and unplugged versus charging conditions prevent attributing the difference solely to the cache change. The faster isolated setup benchmark remains valid for setup only.

Both trials reported unplugged power and Low Power Mode off. The app battery reading went from 80% to 75% during 3D, then stayed at 75% during 2D. Subsequent screenshots showed 77% and 76% in the status bar while the app reported 75%. The app gauge is therefore too coarse to treat the five-point change as exact consumption. These short sequential samples do not establish battery life or relative energy use; a longer controlled unplugged comparison remains appropriate.

Separate visual runs used device screenshots and programmatic orientation changes. Active vials and controls remained in frame in the sampled [3D landscape](ipad-3d-landscape-active.png), [3D portrait](ipad-3d-portrait-pour.png), [2D landscape](ipad-2d-landscape.png), [2D portrait](ipad-2d-portrait.png), [Classic landscape](ipad-classic-landscape.png) and [Classic portrait](ipad-classic-portrait.png) views. These are actual iPad app captures, not touch-driven automation or exhaustive checks of every trajectory. One initial capture caught the system rotation animation and was excluded. The device was returned to its original landscape-left orientation.

The [Classic visual/control run](ipad-classic-visual.json) completed 20/20 pours, including shared receivers, and passed all control checks. Its timing is not used as a clean performance sample because screenshots and rotation occurred during the run. Visual inspection exposed a remaining cosmetic issue: the blue completed-vial cap in the Classic portrait capture draws over a moving green source passing in front of it. Caps currently live in a separate overlay above the board; that ordering needs a follow-up correction. This is separate from rejected or stuck pours.

A USB display/GPU profile is pending confirmation of wired transport. CoreDevice still reported local-network transport during these checks. The prior failed wireless traces are not reused as evidence. A touch-based assessment of the new motion remains a user check.

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
