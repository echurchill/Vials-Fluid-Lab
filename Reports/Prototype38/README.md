# Prototype 38 — concurrent ordinary pours in every lab

September 21, 2026. Requested by Eddie after reviewing the Sorting-only restriction.

## Behavior

- Sorting, Discovery, Density, Mixing, Recovery and Crossover accept concurrent ordinary pours in Classic, 2D Fluid and 3D Fluid.
- Each receiver retains two active approach lanes. Additional accepted pours wait in reservation order. Capacity is reserved against the projected board; a receiving or queued vial cannot become a source.
- Equal-density arrivals use reservation order, even if a shorter animation finishes first. Independent receivers can finish independently.
- Machines remain globally serialized with pours and reveals. Both UI and direct session calls prevent starting a pour during a transformation or a machine during a pour. This is the intentionally limited first pass, not per-machine concurrency.
- Discovery reveals each completed source independently over 0.5 simulation seconds. Unrelated pours continue. Only the revealing vial stays reserved until its fade finishes; pause/suspension freeze the fade. Actual hidden colors are not exposed through projected board state, hints or accessibility. Discovery knowledge still persists through Undo/Reset/save.
- Density bands account for every incoming stream and its joined volume. Existing equal/heavier liquid stays below the incoming batch; lighter layers rise. Concurrent 3D plumes use the existing optical thickness pass.
- The 2D invisible funnel begins guiding earlier above the lip for small shared receivers; its throat extends slightly below the rim. This fixes a six-droplet rejection in a 96-particle single-unit stream without increasing the 5% correction allowance.

## Validation

`Scripts/validate_lab_concurrency.sh` covers 18 lab/presentation combinations with simultaneous shared and independent receivers, a queued third source, reserved capacity, deterministic order, pause/suspension, save and Undo. Additional tests exercise different-density and equal-density/different-pigment arrivals, pre-final-settle descent in 3D, Discovery reveals overlapping another pour, accepting unrelated input during a reveal, machine exclusivity, pours after machine use and Reset cancellation. All pass.

Existing Sorting concurrency regressions pass, including Valve Circuit retained-source/receiver stability, shared-receiver streams and controls. All 19 experimental Classic session routes pass with production concurrency enabled. Existing single-pour density trajectories pass in both particle renderers, including descent through light fluid, equal/heavier boundaries, pause, volume and final completion.

Mac UI: observed overlapping 3D pours into Color wheel's mixer inputs, both completing, and the machine becoming ready and finishing. Also exercised a 2D Discovery pour while another source was still active, including pause/resume. Caffeinate was active during UI checks. Selected offscreen frames are included; they are validation evidence, not physical-iPad acceptance or a device-performance measurement.

Vial profile geometry, dimensions and camera/layout definitions compare unchanged against pushed baseline 59f44e9 (see geometry-preservation.txt). No new geometry or display-scale policy.

Final-build Mac UI retry: Relaxed 2D First reveal B→D completed and revealed the retained color. Then A→D and B→C overlapped, both committed, both destinations capped and Next: Peek ahead appeared. This retry used the final funnel fix; the earlier running build had rejected B→D. The final Mac app is left at completed First reveal, 2D Fluid, Relaxed.

Mac and signed iOS Release builds succeeded. Build logs are available in `/tmp/vials-concurrent-labs-final-mac.log` and `/tmp/vials-concurrent-labs-final-ios.log`.

## Remaining

The physical-iPad spot check is now complete (see follow-up below). Longer unplugged battery measurements and independent machine operations remain deferred. Work remains local/uncommitted/unpushed with the earlier Prototype 37 changes. The unrelated root PNG is untouched. The scheduled performance monitor remains paused.


## Physical iPad follow-up — September 21

Eddie connected and unlocked the M4 iPad. Installed the signed final build. Device Hub's accessibility interface timed out; QuickTime → New Movie Recording → Screen → Eddie’s iPad Pro provided a usable live preview without recording. Enlarging the preview via its zoom action resolved an initially tiny screenshot.

Five foreground, opt-in trials completed, with **56/56 measured pours committed**, no rejected/stuck pours, and nominal thermal state throughout. Every run reached two simultaneous pours and shared receivers. Density's seven control checks (pause, resume, suspension, Reset, commit, Undo, save/reload) passed in all three presentations: 21/21. Discovery ran with actual unknown parcels in 2D and 3D; hidden portions and later revealed colors were inspected in the preview alongside ongoing pours.

| Trial | Committed pours | Max shared receiver pours | Max cleanup | Median / p95 controller interval (ms) |
|---|---:|---:|---:|---:|
| ipad-density-2d | 14 | 2 | 1.04% | 17.77 / 17.88 |
| ipad-density-3d | 13 | 2 | 0.47% | 17.86 / 20.34 |
| ipad-density-classic | 8 | 2 | 0.00% | 17.90 / 18.02 |
| ipad-discovery-2d | 14 | 2 | 2.60% | 17.77 / 17.85 |
| ipad-discovery-3d | 7 | 2 | 0.47% | 17.77 / 17.94 |

The 3D density trial recorded median 10.21 ms combined GPU work (surface 1.16 ms; lanes 9.02 ms), with controller intervals around 17.86 ms median. These are controller/GPU diagnostic counters, not compositor FPS. The iPad was charging and screen-sharing; these short runs do not establish battery life or a controlled before/after performance comparison.

Returned the iPad to normal launch with no trial flags, visually confirmed Crossover → Twin products → 2D Fluid / Quick, 3 existing moves. Mac remains at completed First reveal / 2D Fluid / Relaxed. No code changes were needed following the iPad checks. Physical checks covered Density and Discovery; the six-lab rules/machine matrix was tested on Mac. All work remains unpushed.
