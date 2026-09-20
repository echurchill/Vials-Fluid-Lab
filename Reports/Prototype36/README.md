# Density guidance and physical-device review

September 20, 2026; follows pushed checkpoint f612b33.

## Player guidance

Density and Crossover show a permanent compact legend using the same pale upward Light, plain Medium and dark downward Heavy swatches as the fluid and target strips. Its info button explains pigment versus density and that strips read left to right, bottom to top.

Target cards have a stable-height status line: missing/extra units, wrong colors, layer order, too heavy/light, mixed density, or matched. On a committed pour into a target, the notice explains the mismatch; selecting that target repeats the explanation. VoiceOver includes it too. No puzzle rules or completion criteria changed. Feedback is shared by Classic, 2D and 3D, and Mixing targets receive the applicable color/quantity/layer checks.

Model fixtures cover ten target cases plus absence of targets in Sorting. The full 31-level model check passes; the 15 experimental-session routes and persistence pass, including a new wrong-density pour/selection/VoiceOver/Undo check. Mac UI verified the guide and the actual 3D Medium Ember→Heavy Ember target mismatch, then verified that the same feedback persists in 2D and Classic.

## Surface profile protocol

Two signed Release builds use the identical opt-in `--lab-trial --profile-density-surface --keep-awake` harness. Baseline source is commit 083d383 (before the density-pattern attachment); current source contains the density motifs and guidance. The baseline is an isolated archive under ignored build/density-surface-baseline; the working checkout is not reverted.

The connected M4 iPad renders fixed six- and ten-vial same-pigment heavy/medium/light stacks and the 22,400-particle Sixfold board. Each scene uses 720×432 and 1000×600 targets, 20 warm-up frames, and 120 measured frames. These are offscreen Metal command-buffer GPU durations with frozen particles: fluid surface reconstruction, glass and composition are included; simulation, UI and presentation are excluded. The normal trial presentation is Classic and paused to avoid competing live 3D work. No builds or screen capture during sampling. Completed order: baseline, current, current, baseline, followed by reinstalling the current app.

These measurements isolate rendering cost; they cannot establish displayed FPS or battery consumption. Visual/touch acceptance is recorded separately.

## Measured physical-iPad rendering result

All four runs completed with nominal thermal state. Each retained scene/resolution has 120 measured GPU durations per run (2,880 measured frames overall). Values below average the two per-run medians; the raw JSON retains all samples and individual-run medians.

| Scene | Width | Before | Current | Change |
| --- | ---: | ---: | ---: | ---: |
| six-density-vials | 720 | 1.742 ms | 1.759 ms | +1.0% |
| six-density-vials | 1000 | 2.383 ms | 2.403 ms | +0.8% |
| ten-density-vials | 720 | 2.254 ms | 2.273 ms | +0.8% |
| ten-density-vials | 1000 | 2.731 ms | 2.726 ms | -0.2% |
| sixfold | 720 | 2.578 ms | 2.559 ms | -0.7% |
| sixfold | 1000 | 3.910 ms | 3.456 ms | -11.6% |

The density-heavy fixtures are within about 0.02 ms / 1% of baseline. This comparison shows no material surface-cost regression and does not justify reducing density-symbol quality. The lower Sixfold/1000 result should not be treated as an optimization claim: this is a short offscreen sample, and its per-run medians vary. No simulation, displayed-frame or energy improvement was established.

Reports: [summary](surface-summary.json), [baseline 1](ipad-surface-before-1.json), [current 1](ipad-surface-after-1.json), [current 2](ipad-surface-after-2.json), [baseline 2](ipad-surface-before-2.json).

## Physical-iPad visual review completed

The QuickTime preview became accessible after opening an actual New Movie Recording window and selecting **Screen → Eddie’s iPad Pro**. No reboot was required. Earlier timeout reports below/in the handoff are historical. Inspection used the live iPad preview through CUA, with Eddie rotating the device; no recording was started or saved by the agent.

Inspected Shades of blue in Classic, 2D and 3D in landscape and portrait: Light up-triangles, plain Medium and Heavy down-triangles remain distinguishable, with visible legend and target swatches. The 3D motifs are softer than their 2D counterparts but recognizable. Inspected the ten-vial Twin products layout in 2D landscape and all three presentations in portrait: both target cards, quantity feedback, legend, apparatus controls and bottom toolbar fit without clipping or overlap. Small portrait vials retain the established board framing; no geometry/camera changes were made.

A launch-only wording bug was found: initially opening/restoring an experimental lab retained Sorting’s “matching color” instruction. The shared session initializer now selects the appropriate instruction by discipline, matching the existing reset/switch behavior. All 15 experimental-session routes assert the correct launch guidance and pass. Mac and signed iOS Release builds pass. The updated build was installed, and “Match the outlined target vials” was visually verified on Density and Crossover on the physical iPad.

This closes the pending layout/symbol inspection. These were passive live-preview checks with diagnostic fixture launches, not a new touch-latency or frame-by-frame animation acceptance test. The earlier 12-case live density-control result and controlled GPU comparison remain the functional/performance evidence; neither was rerun for this text-only fix. Inline CUA captures were inspected; no screenshot files were added. Mac automation used caffeinate.

## Final validation

Both final Mac and signed iOS Release builds passed. The guidance build passed all 12 live iPad density-control cases (ipad-density-controls.json); the final layout-only refinement puts the legend beside apparatus buttons where they fit and stacks them on narrower windows. Its final Mac relaunch confirms guide, legend, target accessibility and controls are present. Fill-only target inspection also passes without allowing it to pour. The final signed build is installed and launched normally on iPad, with no trial arguments. caffeinate was used during Mac automation. Eddie subsequently requested that this guidance, validation and design work be committed and pushed together.

## Publication status after visual review

Guidance, GPU results and the obscured-fluid proposal were pushed as d7a88757575f14767423a5a8663606e1a61137fe. Eddie requested that the subsequent launch-instruction fix, its regression assertion and this visual-review update be committed and pushed together as the next checkpoint. Use the Git log and remote head for its publication status.
