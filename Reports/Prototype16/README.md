# Stable idle detail and iPad verification

Eddie observed vertical lines appearing in non-green liquid and extra lines in green when unrelated pours started and ended. The new idle Canvas added two broad ribbons to every color and was removed wholesale whenever any pour began. Green already had its own material ribbons, so these were both duplicate details and a source of visible discontinuity.

The extra idle ribbons have been removed. The remaining specks/bubbles and faint below-surface ripple stay attached to untouched vials throughout other pours. Only the active source and receiver omit those static-position details while their liquid moves. Green retains its existing material ribbons. Native SwiftUI captures of an orange C→B pour confirm consistent decoration in untouched A/E: [before](before.png), [during](during.png), [after](after.png). These offscreen captures have different sampling times and are not a pixel-identical animation test.

macOS and signed iOS Release builds passed. The corrected normal app was installed and launched on Eddie's iPad with saved app data retained. The temporary `devplaceholder.A4UPBIXV.VialsPolishTrial` app was removed after testing. No changes were pushed.

## Two-minute device trial

M4 iPad Pro, wired USB, 2D Fluid / Quick / Green arrival, separate Release app. This trial used d4e0877 before the idle-only ribbon correction; it validates the updated pour motion and controller behavior, not the final idle decoration. It ran without Instruments attached. The idle correction does not change the solver or controller.

- 120.081 seconds, 32 successful pours, median completed pour 3.614 seconds.
- 6,638 controller updates: median 17.768 ms, p95 17.953 ms, maximum 26.658 ms; one interval over 25 ms.
- Worker solver wall time: median 3.239 ms, p95 4.791 ms, maximum 6.087 ms.
- Pause, suspension, resume, reset, commit, Undo and save/reload checks all passed.
- Temperature remained nominal and Low Power Mode was off. The iPad was charging; this is not a battery-drain trial.

The prior Prototype12 two-minute run completed 32 pours with median 3.631 seconds, and the Prototype11 unplugged baseline had median 3.633 seconds. The latest cadence is similar. Controller intervals are not compositor FPS, and worker wall times exclude Canvas rendering. [Raw trial](ipad-120s.json).

## Corrected idle profile

After the ribbon fix, the separate app loaded an idle 2D Deep current fixture and was recorded with Game Performance over USB: 25-second request, 20-second retention setting. The useful retained CPU sample span was 12.621 seconds; display attribution covered 12.417 seconds. The exported launch target was Vials Fluid Lab, PID 22689, using the disposable bundle. A sampled `LabIdleFluidDetail` drawing symbol confirms that the idle view was active.

- 150 app-attributed displayed frames, approximately 12.00 frame changes per second; median display interval 83.334 ms, maximum 87.502 ms. This matches the intentional idle animation rate, not the active-pour frame rate.
- 363 ms total running CPU sample weight over the retained CPU span: about 28.8 sampled ms per observed second across threads; main-thread weight about 26.5 ms per second.
- 152 assigned GPU frames: median active union 0.100 ms, p95 0.101 ms, maximum 0.102 ms. This excludes compositor work.
- No potential main-thread hangs over 100 ms. No physics solver or full-fluid drawing functions appeared in the CPU samples; absence in a short sample is not proof of zero cost.

There is no matched idle baseline here, so this records the cost of the corrected effect rather than a claimed improvement or battery-life result. [CPU analysis](ipad-idle-cpu.json), [render analysis](ipad-idle-render.json). Full trace and exports are on the external drive under ignored `build/polish`.

The Mac's interactive accessibility window was still unavailable. Native offscreen rendering and iPad measurements above do not establish that the pending manual touch-down UI check was completed. `caffeinate -di` was used throughout this test session.
