# Real-time 2D execution

The normal **Vials Fluid Lab** scheme now runs Release. **Vials Fluid Lab Debug** retains an unoptimized build for source debugging. Debug physics is unsuitable for judging animation performance: the prior implementation measured 36.8 ms per nominal solver update in Debug versus 1.45 ms in Release on this Mac, before any drawing.

The 2D solver is now a Sendable value owned by an isolated worker actor during live turns. The main actor receives completed snapshots; asynchronous Canvas rendering reads those snapshots without sharing a mutable engine. Pause, suspension and reset invalidate pending worker results. The worker clock sleeps only for the remainder of the update interval, rather than adding a full sleep after its work.

Delayed frames retain their elapsed simulation time. Each worker batch performs at most 12 fixed steps, with remaining time carried into subsequent updates. This preserves the 120 Hz physics step without silently discarding every delay beyond 50 ms. A persistently overloaded Debug build can still fall behind; retaining elapsed time cannot make unlimited work free. Explicit pause and suspension restart the clock rather than adding time spent away from the board.

The game rules, fluid materials, particle count, fill bounds and Quick choreography are unchanged. Shape calculations and board state are plain Sendable values; 3D GPU code is unchanged. The Classic clock keeps its previous behavior.

## Measurement scope

Trials use the actual SwiftUI app window, Green arrival and Quick pace in an optimized macOS build. Timing instances have a separate bundle identifier and do not save gameplay progress. Reports measure elapsed committed-turn durations and controller/draw callback intervals. They do not measure compositor presents or establish battery life. No new total GPU rendering-cost claim is made for Canvas.

The recorder retains long active-frame intervals rather than filtering out all intervals over 250 ms. Trial reports can be directed to a chosen directory with `--report-directory`, avoiding dependence on a personal Documents folder.

## Reproduction

Run `bash Scripts/validate_fluid_2d.sh /tmp/vials-realtime-check` for physics and session checks. In Xcode, use the normal Vials Fluid Lab scheme for performance comparisons. The separate Debug scheme retains breakpoints and unoptimized local-variable inspection.

For on-screen trials, launch the Release app with `--lab-trial --presentation fluid2D --pace quick --puzzle greenArrival --seconds 40 --exit-after-trial --report-directory /tmp/vials-timing`. Repeat with `classic` and `fluid`. Keep its window open and active. On macOS, activating an existing app after launch may be necessary to open its initial window; a process without a window is not a valid on-screen trial.

## Measured on-screen results

The same first eight Green arrival moves, Quick pace, on this Mac:

| Presentation | Median turn | Turn range | Median callback interval |
| --- | ---: | ---: | ---: |
| classic | 4.78 s | 4.77–4.79 s | 17.22 ms |
| fluid2D | 3.62 s | 3.34–3.83 s | 17.71 ms |
| fluid | 4.34 s | 3.97–4.71 s | 20.00 ms |

All matched moves committed successfully. These results compare completed animation durations, which include the different authored choreography; they are not a ranking of maximum renderer throughput. The 2D trial completed ten turns in 40 seconds, with a full observed range of 3.34–3.97 seconds. Its p95 callback interval was 17.84 ms and its maximum was 29.53 ms. The active app used the real materials and Canvas renderer.

[Timing summary](timing-summary.json) · [Classic report](trial-greenArrival-classic-quick-automatic.json) · [2D report](trial-greenArrival-fluid2D-quick-automatic.json) · [3D report](trial-greenArrival-fluid-quick-automatic.json)

## Regression checks

All 98 solution moves across all 12 authored puzzles passed after the value/worker conversion. Selection and cleanup surface shifts remained zero. Maximum final height error was 0.361% of vial height; maximum missing-particle correction was 0.521%. Inactive particles and material clocks remained stationary, and sampled vial silhouettes did not intersect. [Full replay results](validation.json).

The Green arrival route also passed at [30 fps](30fps.json) and with [Relaxed pacing](relaxed.json). Session tests cover retained delayed-frame time, bounded batches, independent snapshots, the real asynchronous clock, pause/suspension, reset while a turn is active, subsequent commit, save/reload, three-way presentation switching, cross-presentation undo and operation without a Metal simulation device. [Session results](session-validation.txt).

The final optimized macOS and signed iOS builds succeeded. The existing user gameplay instances were left open throughout the timing trials.

The optimized iPad update installed successfully. Launch was denied because the iPad was locked, so the timing comparison above is Mac-only; no new iPad or battery timing claim is made.
