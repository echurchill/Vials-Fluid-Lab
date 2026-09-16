# More visible 3D glass and USB rendering measurements

A tester found the 3D vial edges too fine and transparent. The board glass shader now blends a broader neutral gray edge along the silhouette, widens and brightens the mouth rim, and gives the foot a stronger outline. A screen-derivative minimum helps the rim survive reduction to the rendering resolution. Derivatives are evaluated before the liquid-depth early return, avoiding calculations inside divergent control flow. The center of the glass still shows the liquid. Selection and destination cues retain their existing treatment.

The change affects only `labBoardGlassFragment`, used by the 3D comparison board. It adds arithmetic inside the existing glass pass, with no new draw pass, texture or particle work. It does not change the Classic/2D appearance, original study renderer, puzzle rules, reservations or pour motion.

## Visual and functional checks

Compare [before](glass-before.png) and [after](glass-after.png) native captures, plus the [portrait overlap](glass-portrait.png). The final shader passes the existing overlap suite: all 30 transfers finish; 3D has no sampled physical intersections, and 2D/3D have no sampled clipping. See [results](overlap-summary.json) and [log](overlap.log). These probes sample finite paths and do not prove every possible trajectory. Classic's placeholder geometry counters are not a quantitative Classic geometry check.

Signed iOS Release and macOS Release builds pass. The stronger glass was installed on the M4 iPad Pro and inspected in [landscape](ipad-landscape.png) and [portrait](ipad-portrait.png). The [visual trial](ipad-visual-trial.json) completed 24/24 concurrent pours in 60.981 seconds with maximum cleanup 0.938% and nominal thermal state. Screen capture/rotation makes this a visual/functional check, not a clean timing or energy baseline. These iPad captures and that trial preceded the final derivative-order cleanup; the final compiled shader is covered by the native overlap checks and final device installation.

## USB display/GPU profiles

CoreDevice confirmed wired transport. The 35-second recording stalled during finalization, was stopped at its bounded timeout, and failed export with “Document Missing Template Error”; it is rejected. Shorter Game Performance recordings requested 15 seconds with a 12-second rolling window and successfully exported app-attributed GPU intervals, displayed surfaces and potential hangs. Their retained display windows are shorter than the requested duration. The trace target is `Vials Fluid Lab`, launched with Green arrival, Quick pace, concurrent pours and automatic quality at 1000 maximum render dimension. The app was installed directly under its normal development bundle, following the user's authorization to reset development sessions.

| Capture | Retained display span | Unique frames | Frame changes/s | GPU median / p95 / max (ms) | Display p95 / max (ms) |
| --- | ---: | ---: | ---: | ---: | ---: |
| [Before edge change](ipad-usb-before.json) | 8.275 s | 422 | 50.88 | 7.795 / 15.240 / 60.566 | 33.332 / 91.669 |
| [First edge pass](ipad-usb-first-edge-pass.json) | 8.333 s | 420 | 50.28 | 7.852 / 16.748 / 60.945 | 25.000 / 200.001 |
| [Final edge shader](ipad-usb-final.json) | 9.225 s | 482 | 52.14 | 7.769 / 12.720 / 55.844 | 25.000 / 70.834 |

All three report zero potential main-thread hangs above the template's 100 ms threshold. The first edge pass precedes the derivative-order cleanup; the final capture uses the final installed shader. All samples are reported, including the first edge pass's 200 ms display gap. Median app GPU work remains near 7.8 ms and observed throughput near 50–52 frame changes/s. The final sample does not reproduce the 200 ms gap. These short, sequential windows do not establish either a repeatable regression from stronger edges or a performance improvement. They do establish that overall 3D playback still falls short of a sustained 60 displayed changes/s in this workload. Longer controlled sampling and correlation with pour phases are needed to locate the remaining stalls.


The GPU figures merge overlapping active intervals per app-attributed frame and exclude compositor GPU work. Display figures track first appearances of unique app frames; they are not controller counters. Samples include automatic turn boundaries. A maximum gap alone does not establish a repeatable animation hitch or its cause. USB charging observations are not battery-drain measurements. `caffeinate -di` was active on the Mac throughout these checks.

Full traces and XML remain in ignored `build/overlap-performance/ipad-usb*` folders. The analysis uses the existing `Reports/Prototype11/analyze_render.py` with the verified process name `Vials Fluid Lab` and platform `iPad`.

## Remaining work

The stronger outline is ready for the tester's readability assessment. Sustained 3D frame pacing remains an optimization target. The previously observed completed-cap overlay ordering issue is a separate follow-up; this shader change does not fix it. The inherited solver patch remains reviewed but unapplied, as recorded in `Reports/SolverPruningReview`.
