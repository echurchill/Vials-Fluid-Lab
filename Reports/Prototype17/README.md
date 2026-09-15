# Pause-aware motion and concurrent pours

The idle specks and bubbles now use accumulated running time rather than calendar time. Pausing, opening an overlay, suspending the app, Reduce Motion and the existing economy settings freeze their phase. Resuming continues from that phase. The pour driver also discards elapsed wall time across pause/background transitions, including a period when the operating system suspends the task itself.

## Play behavior

- Classic, 2D Fluid and 3D Fluid allow two independent pours to move at once. Additional accepted pours wait in a queue; source badges distinguish “Pouring” from “Queued.”
- A source already involved in a pending pour cannot be reused. A stationary receiver can accept another compatible reservation when it has enough remaining capacity. Two pours into the same receiver execute in order; they do not send simultaneous streams into that receiver.
- Reservations include color and volume against the projected board. A three-unit pour followed by a second three-unit source into the same empty receiver reserves three units and then one. Already accepted moves finish even if an earlier completion temporarily makes the committed board solved.
- Pause and app suspension freeze every active pour and queue dispatch. Reset cancels active and queued work. Undo becomes available when all accepted pours finish and follows completion order.
- Saves contain committed moves only. Closing during overlapping pours retains completed moves and discards unfinished reservations on reload. Presentation, pace, puzzle and comparison changes stay unavailable during a pour.

Each fluid simulation owns its source/receiver pair. Other moving particles are excluded from its solver inputs, then each pair’s results and vessel poses are combined for display. Two 3D solver instances are prepared in advance; only the combined board gets surface rendering. 2D runs its solvers on an actor and rolls back any worker batch overtaken by pause. Idle decoration excludes every moving pair.

A new partial-fill fixture caught a 2D issue where selected same-color particles could remain mixed into retained source units. The outgoing band now stays above the retained portion, consistent with the 3D solver. The cleanup tolerance remains 5%.

## Validation

- New [concurrency regression log](validation-full.log): all three presentations, simultaneous and staggered starts, two-active limit, third queued pour, shared receiver order, partial-capacity reservation, intermediate solved state, pause/suspension, partial save, completion-order Undo and reset. The real 2D actor clock also passes pause and reset during worker activity.
- The idle-clock check covers a long pause, exact resume and repeated suspension. This is a deterministic clock test; the device control check exercises pour playback. Manual inspection of the idle detail on resume remains useful.
- The [existing 2D suite](planar-summary.json) passes 116 transfers across all 12 authored puzzles plus Relaxed and 30 Hz fixtures. Every reported transfer meets its fill-height, settled-particle preservation, inactive-vial, no-intersection and cleanup checks. Maximum cleanup is 0.521%. Existing [session checks](session.log) pass.
- Native offscreen captures show overlapping source motion: [Classic](classic.png), [2D](fluid2D.png), [3D](fluid.png). These are renderer captures, not touch-driven UI automation or compositor performance measurements.
- macOS and signed iOS Release builds pass. Mac checks run with `caffeinate -di`; the locked desktop prevented a live Mac UI automation pass.

Reproduce the new suite using a built macOS Metal library:

```sh
bash Scripts/validate_concurrent.sh path/to/default.metallib build/concurrent
bash Scripts/validate_fluid_2d.sh build/concurrent/planar
```

## iPad measurements

Separate Release trial app on Eddie’s M4 iPad Pro, iPadOS 27, Green arrival / Quick, wired USB and full battery. These are short active-play checks, not battery-drain measurements. Controller intervals are not compositor FPS, and solver wall time excludes SwiftUI/Canvas drawing. Individual move durations start when dispatched, excluding queue wait.

The [2D run](ipad-2d.json) lasted 120.021 seconds and completed 49 of 49 recorded pours successfully, with two active together and no cleanup corrections. Median move duration was 3.726 seconds. Controller intervals: median 17.763 ms, p95 17.918 ms, maximum 22.102 ms, none above 25 ms. Combined worker solver wall time: median 3.260 ms, p95 5.090 ms, maximum 6.332 ms. Temperature remained nominal. Pause, suspension, resume, reset, commit, Undo and save/reload checks passed.

This 2D device run predates the final background-clock-gap and intermediate-solved-state guards; those guards pass the expanded Mac regression and are included in the subsequent device build. The throughput is higher than the earlier single-pour trial, but the concurrent scheduler takes a different legal route, so the counts are not an exact speedup benchmark.

The 3D device trial could not start: iPadOS reported the device locked after the 2D trial and again on retry. All three presentations pass the Mac concurrency regression, but no concurrent 3D iPad performance result is claimed. Manual touch-driven checks and final idle-animation resume inspection also remain for the next unlocked session.

The final normal iPad app was installed successfully with its saved data preserved. It has not been launched after this installation because the device is locked. The disposable trial app was removed. Changes are committed locally; no push was requested.
