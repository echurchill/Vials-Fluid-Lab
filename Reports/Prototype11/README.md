# Finished-build profiling

Profiled the Release game at `4c44f29`, including the 2D glass, interaction cues and comparison menu. The game code was not changed during this pass. Disposable app identifiers kept the measurements separate from the user's saved progress.

## Clean unplugged iPad trial

Eddie’s 13-inch M4 iPad Pro, iPadOS 27, September 10, 2026. The final build ran Green arrival in 2D Fluid at Quick pace for 600.05 seconds. The device remained unplugged, Low Power Mode was off, and all recorded thermal states were nominal. There was no profiler or mirroring attached during this trial. Brightness was left as found and was not instrumented.

| Measurement | Result |
| --- | ---: |
| Completed pours | 161; all successful |
| Median completed pour | 3.633 s |
| First / last complete nine-move cycle median | 3.628 / 3.630 s |
| Median / p95 controller interval | 17.770 / 17.935 ms |
| Maximum controller interval | 19.924 ms |
| Intervals over 25 ms | 0 of 33,283 |
| Median / p95 worker solver time | 2.766 / 4.226 ms |
| Largest particle cleanup | 0% |
| Reported battery | 70 → 70% |
| Control checks | Pause, suspension, resume, reset, commit, undo and save/reload all passed |

The prior Prototype 09 trial also completed 161 pours, with a 3.635 s median and 17.936 ms p95 controller interval. This sample shows no sustained slowdown after adding the glass and feedback. These intervals measure the controller, not displayed frames or total Canvas rendering time. Battery readings are coarse: staying at 70% does not mean zero energy use and does not establish hours of battery life. Nominal thermal state is an OS pressure report, not a measured physical temperature. [Raw final iPad result](ipad-2d-10min.json).

## What the profiler established

The Mac Time Profiler capture sampled 25.4 seconds of active 2D play. Across 11,212 ms of sampled running-thread CPU weight, a conservative stack classification attributed about 26.4% to the physics worker, 7.6% to other app-authored 2D drawing, 2.0% to glass drawing and 4.2% to board controls/layout. Another 42.5% was classified as UI framework work; the rest was framework/runtime work. These are heuristic shares of sampled CPU work across threads, not percentages of total device CPU capacity or energy. Inclusive function costs overlap and must not be added together. [CPU summary](mac-cpu-summary.json).

This makes reducing unnecessary UI invalidations a better candidate to investigate than removing the glass detail. In particular, each published planar frame currently invalidates the session observed by the board, and status refreshes publish the phase even when its text has not changed. Separating the fast-changing liquid view from the slower board controls is a candidate optimization, not a measured saving. Profile it before adopting it, and retain the existing worker, pause and snapshot guarantees.

A separate Mac Game Performance recording retained a short window of GPU and compositor data. For 318 app-attributed GPU frames, the union of active GPU intervals per frame had median 1.115 ms, p95 1.322 ms and maximum 1.903 ms. Overlapping vertex/fragment intervals were merged rather than added. This excludes the system compositor's work. The observed first appearances of 316 unique app frames spanned 5.63 seconds, averaging 55.95 frame changes/second; median and p95 intervals were 20.00 ms, with a maximum gap of 120.00 ms. This short sample includes automatic turn boundaries, so the largest gap alone is not a validated animation-hitch diagnosis. The trace reported no main-thread potential hangs above its 100 ms threshold. These are Mac observations, not iPad GPU or display measurements. [Rendering summary](mac-render-summary.json).

## iPad USB rendering profile and profiler limitations

The M4 iPad Pro was unlocked, unplugged and connected wirelessly. Instruments could not resolve the running test app by name or verified PID. Launching the app through Instruments started a timed recording, but finalization stalled; export failed with “Document Missing Template Error.” The recording was rejected. The task's stalled profiler process was stopped, after which ordinary device communication recovered.

The app report collected during that attempt showed long stalls and is retained only as a diagnostic artifact. It is not a valid baseline, rendering benchmark or battery comparison. A new ten-minute run was then started with no profiler attached. No other iPad profiling, app installation, screen mirroring or device interaction occurred during that timed sample.

After the clean battery trial was saved, the user connected USB. CoreDevice confirmed wired transport. Attaching by executable name still failed, but direct launch of the disposable bundle through Instruments produced two valid Game Performance traces. Instruments labeled this app `Vials Fluid Lab`; the launch log identifies the disposable `devplaceholder.A4UPBIXV.VialsFluidLabChecks` bundle and the trace target records the trial arguments. No normal saved-game app was profiled or terminated.

The first capture contained only 1.76 seconds of displayed app frames. A second capture requested 35 seconds with a 30-second retention window and retained 12.38 seconds of displayed app frames. The following figures use that longer sample, not the requested duration:

| USB iPad measurement | Result |
| --- | ---: |
| App-attributed GPU frames | 697 |
| Median / p95 / maximum GPU active interval union | 3.300 / 6.301 / 6.706 ms |
| Unique displayed app frames | 694 over 12.383 s |
| Observed app frame changes per second | 55.96 |
| Median / p95 / maximum displayed-frame interval | 16.667 / 25.000 / 91.669 ms |
| Potential main-thread hangs over 100 ms | 0 |

GPU figures exclude compositor work and merge overlapping GPU stages. These are traced frame changes, not a guarantee of continuous 60 fps. The maximum display gap includes automatic play and turn transitions; no separate animation-hitch diagnosis was made. The GPU sample is comfortably below a 16.67 ms frame interval, but GPU work alone is not total frame latency. [iPad rendering summary](ipad-usb-render-summary.json).

The same capture retained 12.43 seconds of CPU sampling: 4,773 ms of running-thread sample weight, with 2,130 ms on the main thread and 2,643 ms on background threads. The heuristic classification assigns 34.7% to physics simulation/worker work, 21.0% to other UI framework work, 8.0% to other 2D drawing, 4.8% to board controls/layout and 4.0% to glass drawing. No main-thread physics samples were observed. Compiler inlining can remove the worker wrapper from iPad stacks, so the analyzer also recognizes the solver/advance functions. These are CPU sample shares, not energy shares. [iPad CPU summary](ipad-usb-cpu-summary.json).

This supports investigating redundant board/status refreshes while retaining the current appearance. It does not establish that reducing UI publications will improve displayed-frame gaps; that requires a before/after measurement. No game code changed in this pass.

The longer export initially failed because the Mac startup disk ran out of working space. This session's temporary builds were removed and completed trace archives moved to the external drive. Sequential exports then succeeded. Full archives remain in the ignored `build/profiling-2026-09-10` directory; aggregated reports contain no target environment dumps.

The profiling app was uninstalled afterward and the normal game relaunched. Detailed Power Profiler energy measurements remain unverified. USB rendering captures are separate from the unplugged battery result; charging measurements cannot establish unplugged battery life. Apple's Power Profiler documentation notes that overall system power is reported as zero while charging.

## Reproduction and interpretation

For CPU profiling, launch an isolated Release app with `--lab-trial --presentation fluid2D --pace quick --puzzle greenArrival --seconds 180 --exit-after-trial --report-directory /tmp/vials-mac-reports`, activate its window, then attach Time Profiler for 25 seconds. Collect Game Performance separately. Its built-in template uses a rolling window; use the retained table timestamps when interpreting the export rather than assuming the requested capture duration is all present.

The accompanying analyzer scripts accept the exported XML and write aggregate app-only summaries:

- `python3 analyze_cpu.py /path/to/mac-cpu-samples.xml /tmp/cpu-summary.json`
- `python3 analyze_render.py /path/to/export-directory /tmp/render-summary.json`

For the latter, export `displayed-surfaces-interval`, `metal-gpu-intervals` and `potential-hangs` into XML files of those names. The scripts default to the disposable Mac process name `VialsProfileChecks`. For these iPad exports, append `"Vials Fluid Lab" iPad` to each command after verifying the trace target and launch log. Both captures used an app-scoped target. They resolve Instruments' reference IDs, exclude unrelated processes, and avoid copying environment variables or unrelated desktop activity into this report. Full trace bundles remain local temporary artifacts because they include system and process metadata.

Apple distinguishes late presented frames from controller callbacks, and Power Profiler reports system power separately from app subsystem impact. The game's callback counters and coarse battery gauge cannot substitute for those measurements. See [Understanding hitches](https://developer.apple.com/documentation/xcode/understanding-hitches-in-your-app) and [Measuring power with Power Profiler](https://developer.apple.com/documentation/xcode/measuring-your-app-s-power-use-with-power-profiler).

For the successful USB capture, use `xcrun xctrace record --template 'Game Performance' --device <iPad UDID> --time-limit 35s --window 30s --output /path/to/capture.trace --launch -- devplaceholder.A4UPBIXV.VialsFluidLabChecks --lab-trial --presentation fluid2D --pace quick --puzzle greenArrival --seconds 120 --keep-awake`. Install the isolated Release app first. Bound the recording command's runtime and accept the trace only after export succeeds. The disposable app has already been removed from this iPad.
