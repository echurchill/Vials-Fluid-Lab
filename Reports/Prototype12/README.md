# Isolated 2D redraws and display-gap investigation

The 2D liquid now publishes completed snapshots through `LabPlanarDisplay`. `LabPlanarSurface` and the optional live diagnostics observe that publisher; board menus, vial controls and comparison controls observe the slower-changing `FluidBoardSession`. Status text is published only when it changes. Both the main board and matched-pour preview use the same arrangement.

The physics solver and `LabFluid2DView` drawing implementation are byte-for-byte unchanged from `39f51cd`. The animation clock, speed, pour assist, cleanup, rules, sound and saved-game format are unchanged. The frame-observing wrappers live in their own source file so standalone renderer comparisons still work.

## Verification

`bash Scripts/validate_glass_comparison.sh build/ui-refresh/validation` passed the comparison and controller suites. A new regression checks that every completed worker snapshot reaches the displayed value, while the board publisher stays quiet between real state transitions. One complete stepped pour produced **200 liquid updates and seven board updates**. Repeated unchanged status refreshes produced no additional board publications. Undo and reset immediately replaced the displayed snapshot. The count excludes the subsequent undo/reset frames. [Publication counts](publication-counts.json), [controller results](session.log).

Existing checks passed pause, suspension, cancellation of in-flight workers, commit, reset, save/reload, cross-presentation undo, immutable snapshots, delayed-frame accounting, preview disposal and fallback without Metal. All nine one-, two- and three-unit comparisons passed across Classic, 2D and 3D. [Comparison results](comparison.log), [raw comparison data](comparison.json).

Live checks in a separate Mac app covered a two-unit pour, pause/resume, committed state, comparison replay/pause, and Stop unlocking the comparison controls. Captures verify both the main board and comparison show the moving liquid while paused. [Board](board-paused.png), [comparison](comparison-paused.png). Final macOS and signed iOS Release builds passed.

## iPad CPU and GPU comparison

Same M4 iPad Pro, iPadOS 27, USB connection, isolated Release app identifier, Green arrival, 2D Fluid and Quick pace. Both binaries included the same opt-in `--trace-pours` markers. The baseline used `39f51cd` game code plus the markers. The optimized binary contained the isolated publishers and conditional status publication. Final packaging moves the unchanged wrapper declarations into their own file.

Both successful recordings used Game Performance, a 35-second recording request and 30-second retention window. The actual retained CPU windows were 14.635 seconds before and 11.275 seconds after; requested recording time is not the available measurement duration. Normalize sampled CPU weight by its actual observation time:

| Measurement | Before | After |
| --- | ---: | ---: |
| Main-thread CPU sample weight per observed second | 175.4 ms | 113.1 ms |
| All-thread CPU sample weight per observed second | 349.5 ms | 321.7 ms |
| Main-thread CPU sample weight per second, pouring phase only | 168.7 ms | 109.2 ms |
| All-thread CPU sample weight per second, pouring phase only | 352.4 ms | 327.9 ms |
| Assigned GPU-frame active union, median | 3.350 ms | 3.240 ms |
| Assigned GPU-frame active union, p95 | 6.325 ms | 6.201 ms |
| Assigned GPU-frame active union, maximum | 6.986 ms | 6.660 ms |
| Potential main-thread hangs over 100 ms | 0 | 0 |

The pouring-only comparison covers 8.775 seconds before and 6.899 seconds after. It suggests about **35% less main-thread CPU work** and **7% less total sampled CPU work** during pouring. Those are short samples, not guaranteed savings across all puzzles or measurements of battery life. The similar GPU timings do not establish a meaningful GPU improvement. No main-thread physics samples were observed.

The stack classification also shows board/control work dropping from 18.6 to 1.8 sampled ms per observed second and other UI framework work from 85.3 to 18.6. Those categories are heuristic and compiler-sensitive; their changes must not be added to an energy estimate. Inclusive function weights overlap.

[Before CPU](ipad-before-cpu.json), [after CPU](ipad-after-cpu.json), [phase-matched CPU](cpu-by-phase.json), [before GPU/display](ipad-before-render.json), [after GPU/display](ipad-after-render.json).

## What the apparent display gaps mean

Optional phase markers identify lifting, positioning, pouring, returning, settling and completion. Short intervals also mark synchronous pour startup and checkpoint work. They are disabled in normal runs.

The trace exports contain missing attribution: 156 of 825 displayed-surface rows in the baseline and 114 of 635 afterward have no app/frame label. A gap between *identified* app frames can therefore contain intervening display updates. Counting that whole gap as an app freeze would overstate what the trace establishes. The raw attributed-frame rates around 46/s are incomplete counts, not reliable app FPS measurements.

For gaps exceeding 33.34 ms:

- Before: 58 contain intervening unattributed surface updates; one other gap coincides with the automated trial's transition between moves.
- After: all 34 contain intervening unattributed surface updates. The largest apparent 141.7 ms gap contains seven such updates.
- The continuously attributed active-pour intervals have median 16.667 ms, p95 25.000 ms and maximum 25.000 ms in both captures (548 before / 446 after intervals). This does not cover the portions with missing attribution and is not a claim of a hitch-free app.

The clearly attributed 79.2 ms baseline gap follows “Move complete” and precedes the next lift. The trial deliberately checks for the next automatic move every 100 ms; this is not continuous pouring. No animation-clock change was justified by that gap. The diagnostic checkpoint maximum was 4.40 ms before and 1.17 ms after, although disposable sessions do not perform normal UserDefaults writes, so those timings do not benchmark persistent disk saves.

GPU intervals lacking a frame ID are also excluded from the per-frame summary. Grouping all missing IDs together would create one fictitious long GPU frame. There are 1,582 such intervals before and 1,190 after; the remaining assigned-frame summaries cover 708 and 546 frames. Vertex/fragment overlap is merged, and compositor work is excluded.

[Before phase/gap analysis](ipad-before-flow.json), [after phase/gap analysis](ipad-after-flow.json). The new analysis distinguishes measurement uncertainty from visible stutter; it does not establish an animation-hitch ratio or prove every frame met its deadline.

## Independent device regression trial

After profiling ended, the optimized disposable app ran for **120.05 seconds without a profiler attached**. USB remained connected, so this is a performance/control check, not a battery trial.

- 32 pours completed successfully; median completed pour 3.631 seconds.
- 6,661 controller updates: median 17.767 ms, p95 17.929 ms, maximum 20.484 ms; zero over 25 ms.
- Worker solver wall time: median 3.259 ms, p95 4.812 ms, maximum 6.044 ms.
- Pause, suspension, resume, reset, commit, undo and save/reload checks all passed.
- Thermal state stayed nominal; Low Power Mode was off. Battery was charging throughout.

The previous unplugged ten-minute trial's median pour was 3.633 seconds. Overall cadence is retained. The worker wall times are higher than that earlier sample, whose median was 2.766 ms; the solver is unchanged and the runs had different charging/profiling history. No sustained slowdown was observed, but the shorter new run does not replace the longer battery baseline. [Raw device trial](ipad-after-120s.json).

## Reproduction and artifacts

Use the same isolated app bundle and `--lab-trial --presentation fluid2D --pace quick --puzzle greenArrival --seconds 120 --keep-awake --trace-pours` for instrumented comparisons. Export `time-profile`, `metal-gpu-intervals`, `displayed-surfaces-interval`, `potential-hangs`, `PointsOfInterestEvents` and `OSSignpostIntervals`. Verify the target bundle in the launch log and target process in the trace before analyzing.

```
python3 analyze_cpu.py /path/to/time-profile.xml /tmp/cpu.json "Vials Fluid Lab" iPad
python3 analyze_render.py /path/to/exports /tmp/render.json "Vials Fluid Lab" iPad
python3 analyze_flow_trace.py /path/to/exports /tmp/flow.json
python3 compare_cpu_phases.py /path/to/before-exports /path/to/after-exports /tmp/phases.json
```

The initial longer baseline capture timed out during finalization and failed export. The shorter retry then explicitly failed with insufficient startup-disk space. Neither is used for measurements. Closed Instruments staging files from today's work were moved to the external drive, after which both captures finalized and exported successfully. Setting a trace destination or temporary-directory environment variable does not relocate every shared developer-service staging file; allow startup-disk headroom too.

Full traces, source/build copies and staging archives remain under ignored `build/ui-refresh`, not in Git. Only app-scoped aggregate measurements and verification evidence are tracked. The disposable iPad app was removed, and the final signed normal app was installed and launched with its saved app data retained. No changes were pushed.

[Tonight’s short testing checklist](TestingTonight.md) keeps matched visual comparisons separate from normal-speed preferences.
