# Prototype 05 measurements

Eddie's iPad Pro 13-inch (M4), iPadOS 27 development build, September 8, 2026. Unplugged, connected to the Mac over the local network. Green arrival, six vials, three colors, Quick pacing; automatic solving and resets. Audio and haptics were disabled in both trials. System brightness settings were left as found and were not instrumented.

| Ten-minute trial | Classic | Fluid |
| --- | ---: | ---: |
| Successful pours | 123 | 134 |
| Failed pours | 0 | 0 |
| Recorded start charge | 100% | 100% |
| Recorded end charge | 100% | 95% |
| Thermal state | Nominal throughout | Nominal throughout |
| Median animation interval | 17.20 ms (controller updates) | 16.67 ms (Metal draws) |
| p95 animation interval | 17.42 ms | 16.72 ms |
| Intervals over 25 ms | 0 of 34,276 | 247 of 35,278 (0.70%) |
| Median / p95 Fluid GPU work | Not applicable | 7.85 / 11.85 ms |
| Largest Fluid cleanup | Not applicable | 0.547% |
| Completed-turn duration | 4.75–4.78 s | 3.93–4.97 s |

Both completed the full 600 seconds without suspension. The recorded maximum Fluid interval was 58.30 ms; maximum GPU work was 49.41 ms. Thus the median cadence was approximately 60 draws/second, with occasional longer frames. Classic samples measure its animation clock rather than compositor presentation, so the two interval measurements are not identical counters.

The Fluid run used the final physics/rendering code. The earlier Classic candidate used the same Classic drawing/animation code; subsequent differences were Fluid guide tuning, options-menu placement and trial metadata. The final optional feedback fix does not affect either trial with sound/haptics disabled.

## What the battery readings establish

The gauge fell five percentage points during the Fluid run and stayed at 100% during Classic. This identifies energy use as a priority for further optimization, but does not establish a drain ratio, watts or hours of battery life. The Classic run started just after unplugging at full charge; the full-charge plateau and coarse gauge can hide consumption. The runs also occurred in fixed order, and Fluid completed more moves in the same time. Repeat below full charge in reverse order before drawing a quantitative battery comparison.

Raw evidence: [Classic](ipad-classic-10min.json) and [Fluid](ipad-fluid-10min.json).

## Rendering budget on Mac

A separate offscreen comparison replayed the same nine-move six-vial solution. High used 1000×650 pixels; Low energy used 720×468. The median of per-move GPU medians decreased from 5.62 ms to 5.34 ms, about 5%. Both runs retained exact inventory, timing, undo, stationary inactive vials and the cleanup bound. This measures the whole GPU command buffer, including physics, so reducing pixels has a modest effect. It is not an on-device battery saving measurement.

Raw evidence: [High](render-budget-high.json) and [Low energy](render-budget-low.json).

## Verification scope

The correctness suite passed 162 transfers: 85 complete new-level Fluid moves, 62 mixed-presentation moves across five puzzles and both paces, six retained Relaxed moves, and nine portrait moves at 30 Hz. The retained two-vial water regression and both nine-move render-budget runs also passed. The largest correction across the main board fixtures was 0.625%, with no sampled glass intersections, nonfinite particles, incorrect color/ownership counts or motion in inactive vials. All 12 authored puzzles have verified legal routes, totaling 98 shortest-route moves.

macOS and signed iOS builds passed. Live Mac checks verified choosing a six-vial level, switching presentations, pouring A→F and undo. Portrait board captures were inspected. Build success and sound-file decoding do not establish subjective sound quality or prove that an iPad has haptic hardware.

The final options-menu check passed on September 8, 2026, using the Prototype 05 Mac build. Pouring sound was enabled and disabled through the menu; saved preferences confirmed both changes. Fluid detail was changed to Low energy, High and Automatic, with each value confirmed in saved preferences. A Quick Fluid A→B pour on Green arrival completed with Low energy and sound enabled, leaving the expected three units in A and one Tide unit in B. Pour study and Original game both opened from the menu and returned to the unchanged board. Undo restored zero moves. The app was left on Green arrival, Classic, Quick, Automatic detail and sound off. No code fixes were needed. This check verifies menu behavior and saved settings; subjective listening and device haptic feedback remain manual checks.
