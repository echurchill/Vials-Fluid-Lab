# Vials Fluid Lab — handoff to the next chat

## September 18 stream endpoint and completed-vial headspace follow-up — latest status

- The tester's 15-second physical-iPad recording was inspected frame by frame around 11–13 seconds. G's particles were already stable while B/C returned; the apparent final fill was the opaque matching cap visually bridging the small air gap, compounded by measuring particle centers rather than the top of their rendered billboards.
- The 3D particle fill calibration now reserves one rendered particle radius below the shared fill line, so the visible particle surface—not merely its centers—lands at the same naturally headspaced level as Classic/2D. Completion caps remain fully outside the vessel cavity and use a neutral dark underside/gasket, preserving an obvious air gap even when cap and fluid colors match.
- Classic pour streams now extend inside the receiver to its live accumulated fluid surface. The endpoint includes every concurrent incoming and outgoing pour's progress and is clamped to the receiver capacity.
- Removed the redundant cyan fill-only glyph drawn inside 3D vessels. Receive-only vials retain the clearer `↓ FILL` badge above the vessel and the compact rule arrow in the information row; their glass now uses the same neutral volume graduations as other vials.
- The exact Level 16 B+C→G regression still records 21 held-source settle frames and 34 position-stable receiver frames during source return; visible headspace is 0.200955 scene units. It also asserts that 3D cap geometry stays outside every 3–6-unit vessel cavity.
- Final macOS verification passes the full concurrency suite, all 18 overlap fixtures, all 16 model solutions, and the complete Five Streams, Tall Order, Sixfold and Valve Circuit 3D/2D routes. A current unsigned generic-iOS Debug build (including the Metal shader) also succeeds. A completed Level 16 visual fixture shows the corrected dark air gap, and a Classic shared-receiver capture shows streams reaching the accumulating surface.
- The iPad stopped appearing in CoreDevice, `xcdevice`, and USB inventory before this latest build could be installed. Earlier Prototype27 device evidence remains valid for framing/layout/concurrency; the final cap/surface calibration still needs a physical-device spot check when it reconnects.
- See `Reports/Prototype27/README.md`. Current branch is `codex/fluid-lab`; inspect the latest log and status for the exact commit/push state.

## September 17 matched 3D framing — supersedes stale visual status below

- The 3D board camera now uses the same normalized board scale as Classic/2D and lens-shifts the common floor to their 82% baseline. Resting vial height differs by at most 15.1% across 4–10-vial boards and six portrait/landscape aspect ratios.
- The large 3D board floor ellipse is gone; localized contact shadows remain. The standalone two-vessel pour study keeps its smaller orientation ellipse.
- The original collision-safe lift/pour/return geometry is unchanged. All 16 solutions and the full Five Streams, Tall Order, Sixfold and Valve Circuit 3D/2D routes pass. The 18-case cross-mode overlap suite reports zero penetration or clipping.
- The per-vial information cards now stay in a single ordered row. Physical M4 iPad checks confirm all 8 cards at normal scale and all 10 denser cards remain readable in landscape and portrait, including counts, capacities, rules and unit colors.
- A signed Release build was installed on the physical M4 iPad Pro. Matching Level 16 Classic/2D/3D captures confirm the new scale, and the B+C→G concurrent replay verifies active framing, continuous final fill and the completion cap. The iPad was returned to landscape-left.
- A later B+C→G physical replay found that G still rose when the cap appeared because final canonical settling followed source return. Shared 3D receivers now settle while sources remain held over them, retain realistic headspace, stay particle-position stable throughout source return, and show the cap only afterward. The focused regression measures 21 held-source settle frames, 34 stable-receiver return frames and 0.20 scene units of headspace; the full concurrent and expanded-level suites pass.
- See `Reports/Prototype27/README.md`. Current branch is `codex/fluid-lab`; inspect the latest log and status for the exact commit/push state.

## September 17 device verification and profiling — supersedes stale status below

- The remaining small end-of-pour jump was a pre-settle teleport of late correction particles. Those particles now remain in place and take the same 0.55-second canonical interpolation while simulation clocks advance without physics. The exact Level 16 B+C→G regression records 21 visible settle frames.
- The signed Release build was installed on the physical M4 iPad Pro. A deterministic two-pass B+C→G replay ended with G continuously filled, its pink completion cap visible, and both pours committed. CoreDevice screen recording is unavailable on this device, so direct screenshots plus the instrumented frame regression are the retained evidence.
- Completed-cap depth ordering was already implemented and physically verified in Prototype23 (`7ff55f9`). The current 18-case overlap suite was rerun with zero penetration or clipping; do not reopen this based on the stale historical list below.
- A 90-second Sixfold / Quick / 3D Fluid trial on the physical M4 iPad reached four concurrent pours and committed 18/18 moves. It remained nominal thermally. At 22,400 particles, median recorded GPU/host wait was about 96 ms, establishing the expanded board as GPU-bound and the next optimization target. USB/full battery observations are not energy evidence. See `Reports/Prototype26/README.md`.
- Current branch is `codex/fluid-lab`; inspect the latest log for the final commit. The earlier work through `8236b50` is pushed.

## September 17 tester follow-up — superseded by the device section above

Eddie approved implementing the previously proposed items 1–4 while the physical iPad was unavailable: per-vial capacities, receive-only valves, larger authored levels, and Mac/Xcode-simulator validation. That work is now implemented locally and documented in `Reports/Prototype25/README.md`.

- The shared Lab progression now has 16 levels. The four new fixed puzzles cover 8–10 vials, 5–6 colors, capacities 3–6, pours up to five units, and two fill-only valves.
- `LabBoardState` carries per-vial capacities/rules with migration for old scalar-capacity saves. Moves, completion, solver canonicalization, reservations, hints, UI and all three renderers use the metadata.
- Full Release validation passes all 175 new-route pours in both 3D and 2D. Reset/progress, concurrent/shared-receiver and overlap regressions also pass in Classic, 2D and 3D.
- A generic unsigned iOS Release build and iOS-simulator build pass. Xcode simulator checks on iPad Pro 13-inch (M5) and iPad mini (A17 Pro) found and verified a ten-vial portrait camera fix. Simulator checks are functional/layout evidence only, not hardware performance evidence.
- Real-iPad screenshots drove three follow-up fixes: Classic/2D no longer draw the confusing extra cyan line inside fill-only vials; hints retain and advance one solved route rather than oscillating between inverse moves; and identical vessel shapes scale vertically from 75% at three units to 150% at six units while preserving per-unit volume.
- Concurrent play no longer has a global two-pour ceiling. Every dependency-independent reservation may start; a source still cannot be an existing source/destination and a moving source cannot become a destination. The regression suite verifies three simultaneous pours in Classic, 2D and 3D plus the existing shared receiver behavior.
- A second physical-iPad follow-up reproduced two remaining defects from exact tester states. The live concurrent-capable session now advances a followed hint along its retained route instead of replanning H→D as D→H. Accepted 3D pours canonically settle only their participating vials, preventing correctly owned particles from freezing as detached clusters while preserving untouched vials byte-for-byte.
- A third device follow-up found that the exact settle could make late fluid appear in one frame and could leave a completed vial's cap hidden in an idle cached frame. The settle is now a 0.55-second interpolation, cap-exclusion changes invalidate that idle cache, and concurrent receiver groups preserve stable particle ordering across unrelated commits. A subsequent refinement removed the remaining correction teleport; the exact Level 16 B+C→G shared-receiver regression now completes with 21 visible settle frames. The full 175-pour 3D suite and all three concurrent presentation suites pass.
- A signed Release build containing these changes was installed and launched on the physical M4 iPad Pro. `Reports/Prototype25/ipad-valve-height-and-marker-fix.png` is a direct device screenshot verifying the 2D Valve Circuit height silhouettes and simplified fill-only marker. It is not a touch or performance test.
- Density remains deferred. Initial real-iPad expanded-level performance is now measured in Prototype26; optimization and controlled unplugged energy testing remain open.
- Current branch is `codex/fluid-lab`. The Prototype25 base is committed and pushed as `3a68289`; inspect `git status` and the latest log for subsequent tester follow-ups.

The older snapshot below remains useful historical context, but its statements that Lab capacities are uniform, there are 12 levels, the Original solver patch is unapplied, or six commits are unpushed are obsolete. Prototype24 already contains the Original-game solver correction, and Prototype25 contains the new Lab work.

Prepared September 16, 2026 for Eddie. This is a context snapshot, not an instruction to implement every idea below. Read the new chat's actual request first, then inspect the current checkout. No implementation work was started as part of creating this handoff.

## Start here: correct project and current state

**Work in `/Volumes/Code Work/xCode work/Vials Fluid Lab`.** The old chat's default working directory is misleadingly `/Volumes/Code Work/xCode work/Vials`, the original game. Do not edit the original by accident. Use an explicit working directory on shell calls.

- Repository: https://github.com/echurchill/Vials-Fluid-Lab.git
- Branch: `codex/fluid-lab`.
- Latest implementation commit: `6df583a` — Add confirmed reset of all game progress.
- Working tree was clean before this handoff file was created. This document is initially uncommitted.
- Local tracking information shows six commits ahead of `origin/codex/fluid-lab`, zero behind. This was checked without fetching; verify the remote before a future push.
- The six local commits, oldest first: `70d8f8b` pour setup cache/travel lanes; `143bc9e` iPad validation; `aef0eba` solver patch review; `bbe76cc` stronger glass/USB profiles; `0c8422d` antialiasing; `6df583a` reset progress. They have **not been pushed** in this chat. The last known pushed implementation is `710c272`.
- Both latest macOS Release and signed iOS Release builds pass. The latest build has not been installed/checked on iPad.
- Last known iPad installation is `bbe76cc`, before antialiasing and reset-all-progress. Do not describe the iPad as running HEAD without verifying/updating it.

Read `README.md`, then `Reports/Prototype22/README.md`, `Reports/Prototype21/README.md`, `Reports/Prototype20/README.md`, and the remaining-work sections of `Reports/Prototype19/README.md`. Reports are incremental history; older statements that an issue is pending can be superseded by later reports.

## Eddie's preferences and standing constraints

- **No Unity.** This is a native Swift + Metal experiment copied from Vials; keep the original project separate.
- Eddie values convincing, readable fluid movement over perfect physical accuracy. Up to **5% final correction** is accepted: a subtle end-of-pour “magic” pass can restore the exact source/destination state. Keep exact logical quantities, legal moves and reservations authoritative.
- Testers generally like the pace and readability. 3D is the visual favorite, 2D is also liked. Do not change the pace arbitrarily in response to performance work.
- Original-game players expect concurrent interaction. Two independent pours and two sources into one receiver are now implemented. Preserve those capabilities.
- **Run `caffeinate -di` throughout Mac UI automation/testing**, and clean up only the assertion process you started. It keeps the Mac awake; it does not keep the iPad unlocked.
- Eddie explicitly permits resetting/relaunching running Mac/iPad development game sessions; preserving his saved progress is not required while building/debugging. Still avoid interrupting active user testing. Check present iPad availability rather than assuming an old “available” message remains current.
- At handoff, a question asking whether the iPad is free for installation/checks of the smoother edges has no recorded answer. No iPad operations were done during the reset feature task.
- Sound is adequate for now; improvements are deferred. Haptics/sound preferences should survive a progress reset.
- Be autonomous within the requested work, avoid repeated permission questions, explain real blockers, and report actual evidence. Do not push merely because old messages in the long conversation asked for earlier pushes; the most recent work was explicitly reported as local/unpushed.
- The user originally requested estimates and asked whether they described human or AI time. Any new estimate should label engineering effort versus expected agent execution time and separate uncertain device/user-validation delays. Historical estimates are not current delivery commitments.

## What the app currently is

The main Fluid Lab board offers **Classic / 2D Fluid / 3D Fluid** presentations of the same 12 authored puzzles, sharing logic, progress, hints and undo. These are different from the bundled **Original game**, opened through the ellipsis Board options menu. That original has its own generated levels, solver, progress, and experimental destination-only levels.

Current capabilities include shaped vessels, geometry-dependent fill heights, translucent/material-specific 2D appearance, stronger source/destination hints, color-matched caps on completed vials, pause-aware animation, concurrent pours, and simultaneous pours into a shared receiver with exact capacity reservations. Invisible capture assistance and bounded final correction stabilize the visual simulation.

The 3D renderer now uses front/back travel lanes to separate moving vials. Classic/2D use stable vial drawing order and smoked/lens-style overlap treatments. Board framing reserves room for edge pours so the camera does not zoom and change apparent liquid levels mid-turn. The earlier stuck-pour and stale-particle problems have fixes plus regressions; treat new reports as evidence to investigate, not as proof the old issue is still open.

Logical Fluid Lab vial capacities are currently uniform (four units), even when shapes differ. A different shape does not yet mean a different logical capacity. Current Lab rules do not model density-driven reordering or real mixing.

## Latest completed changes

### Reset all progress — `6df583a`

**⋯ Board options → Reset all progress…** opens a destructive confirmation with Cancel. Confirming clears all Lab puzzle saves, completions and undo, and bundled Original game progress, scores, ratings and generated variants. It starts First sort / Level 1 in 3D Fluid / Relaxed. Sound, haptics, fluid-detail settings and diagnostic report files remain. The separately installed original Vials app is unaffected.

Active pours and pending worker results are cancelled. Original-game delayed pour completion and detached generation/minimum-move callbacks use a reset-generation token so old work cannot recreate cleared progress.

Validation: `Scripts/validate_reset_progress.sh` passes for all three presentations, including reset during two pours, all 12 initial levels, persistence, undo isolation and retained preferences. Real Mac accessibility UI automation verified the menu, confirmation wording, Cancel preserving Confluence, reset to First sort with zero moves/completions, and persistence after relaunch. A temporary separate-bundle app was used so the normal app's progress was not reset. Mac/iOS builds pass; iPad verification is pending. See `Reports/Prototype22`.

### Smoother 3D glass — `0c8422d`

A tester with difficulty seeing fine lines prompted stronger glass silhouettes/rims in `bbe76cc`. Eddie then reported visible jaggies. The current fix adds **4x MSAA to glass geometry**, with supported 2x/1x fallbacks, preserving the stronger outline. It does not raise particle count or change fluid simulation resolution.

Mac captures, overlap regressions (30 transfers) and GPU command checks pass. A paired Mac render benchmark found +0.025 to +0.224 ms median surface cost depending on view. That is offscreen Mac rendering, not iPad frame-rate/energy evidence. See `Reports/Prototype21` for before/after images and limits. Actual iPad appearance/cost remains to be checked.

## Historical open work — completed or superseded

### 1. Validate the latest build on the iPad when available — completed for the reported fill/cap path

Install the current signed build only after verifying device availability. Check smoother yet readable 3D outlines on **Confluence**, including empty bulb flasks, neck/rims, portrait/landscape and overlapping pours. Check reset-all-progress UI (Cancel and confirm) and re-opened Original-game progress. Exercise concurrent/shared-receiver pours, pause/resume, undo, reset and presentation switching. Keep functional/visual checks separate from clean timing or battery measurements.

### 2. Fix completed-cap overlap ordering — completed in Prototype23

Prototype23 resolved the Classic portrait bug where a completed blue vial's cap drew over a moving green source. Classic/2D caps now participate in the per-vial layer order and 3D caps use the glass depth pass. Physical portrait/landscape checks and the current 18-case overlap regression pass.

### 3. Apply the reviewed inherited solver fix, with regression coverage — completed in Prototype24

Eddie supplied `/Users/eddie/Downloads/vials-prune-fix.patch`; Prototype24 applied the equivalent correction with regression coverage. The review artifact remains in `Reports/SolverPruningReview/{proposed.patch,repro.swift,README.md}`.

Affected code: `Vials/Game/VialLevelGenerator.swift`, `LevelSolver.moves(for:)`, used by bundled Original game. The current solver incorrectly prunes moving a full homogeneous vial into an empty vial when capacities differ.

Counterexample, bottom-to-top stacks: A capacity 2 = Ember/Ember; B capacity 3 = empty; C capacity 3 = Tide/Ember/Tide. Current solver reports dead end. Patched temporary solver finds a four-move solution A→B, C→A, C→B, C→A. Add this regression and check generated levels, duplicate colors, differing capacities, receive-only rules, helper-beaker hints, and node-limit/search-cost effects.

The Lab solver was reviewed separately when variable capacities and destination-only rules were added in Prototype25; its canonical keys and pruning now include that metadata.

### 4. Continue measured 3D performance work — expanded-board baseline captured in Prototype26

Before MSAA, valid short USB iPad traces showed about **50–52 displayed frame changes/sec**, median app GPU active time around **7.8 ms**, and occasional gaps. Sustained 60 displayed updates/sec has not been established. Correlate stalls with setup, commits, receiver joins and surface rendering before further optimization; measure current MSAA build separately.

The seed-position cache genuinely improves isolated setup (median 3.638→0.225 ms), but whole-puzzle measurements did not establish a general frame-pacing improvement. Do not confuse setup speed with displayed FPS. See Prototype19/20.

Longer controlled unplugged battery comparisons remain useful. Testers reported no battery complaint; this is not a battery-life measurement. Coarse battery gauges, USB charging and short sequential runs cannot establish relative energy use.

### 5. Git housekeeping when requested

There are six unpushed implementation/report commits plus this handoff document. Inspect status/remote divergence, include intended work, and push when Eddie requests it. Do not accidentally commit ignored build products or raw traces.

## Future possibilities, not committed implementation scope

- Bring the Original game's **destination-only / receive-only experiments** into the shared Lab board. Revisit legal moves, hints, canonical solver keys, completion criteria, UI indicators and undo together. The original currently has 15 experimental levels; inspect its generator for exact rules.
- More shaped vials, varied logical capacities and asymmetric spouts. Preserve equal-volume/equal-area filling and stable apparent height through selection/pours.
- Density + immiscibility: heavier phases sink through lighter phases; puzzles target layer order. Density, viscosity and miscibility are separate properties.
- Bottom taps/decanting pair naturally with density. They need new outlet rules and deterministic settled transitions.
- Mixing and recipes: an intentional palette (red + blue → purple) with conserved quantities/composition, authored ratios and new completion targets. Do not claim naive RGB averaging is physical dye mixing. Existing same-color destination restrictions must change for this mode.
- Viscosity, surface tension, bubbles/foam, dosing and temperature effects could add variety. Introduce strategic rules only when readable and solvable, rather than making ordinary sorting unpredictable.
- More fluid-looking translucency and low-cost idle detail remain polish options, but earlier green vertical-line flashes were already addressed. Do not reintroduce wall-clock-driven motion that jumps ahead after pause.
- Sound polish is explicitly postponed until Eddie wants it.
- Accessibility/readability: keep stronger glass edges, obvious hints and distinguish completed caps from selection. Preserve reduced-motion/transparency behavior while polishing.

`Reports/3d-fluid-simulation-plan.md` is historical concept material, not the current backlog. Its original Unity comparisons and links into the original project are superseded by the no-Unity decision and independent Lab checkout. Density/mixing should use a distinct rule mode; the stable sorting mode must remain predictable.

## Code map

| Area | Main files relative to Lab repo |
| --- | --- |
| Shared puzzle state, moves, solver | `Vials/FluidLab/LabBoard.swift` |
| Session, saves, pause, concurrency, correction | `Vials/FluidLab/LabBoardSession.swift` |
| Main UI, options, caps and reset confirmation | `Vials/FluidLab/FluidBoardView.swift` |
| 3D rendering/particles and shaders | `Vials/FluidLab/LabBoardRenderer.swift`, `LabShaders.metal` |
| Shapes, camera, travel layout | `Vials/FluidLab/LabBoardGeometry.swift`, `LabGeometry.swift` |
| 2D simulation and rendering | `Vials/FluidLab/LabFluid2D.swift`, `LabFluid2DView.swift`, `LabPlanarSurface.swift` |
| Classic Lab rendering | `Vials/FluidLab/LabClassicBoardView.swift` |
| Trial arguments and metrics | `Vials/FluidLab/LabPerformance.swift` (inspect `--lab-trial` parsing) |
| Preferences, sound/haptics | `LabBoardPreferences.swift`, `LabBoardFeedback.swift` |
| Bundled Original game and solver | `Vials/App/ContentView.swift`, `Vials/Game/VialLevelGenerator.swift` |
| Original progress/result/variant/feedback stores | `Vials/Support/` |

## Builds, tests and device details

Open **`Vials Fluid Lab.xcodeproj`**, shared scheme **`Vials Fluid Lab`**. Run uses Release for realistic performance; **`Vials Fluid Lab Debug`** is the debugging scheme. Product is `VialsFluidLab`, displayed as `Vials Fluid Lab`, bundle ID `devplaceholder.A4UPBIXV.VialsFluidLab`.

Known latest output locations (verify timestamps before installing):

- Mac app: `build/shared/legacy/DerivedData/Build/Products/Release/VialsFluidLab.app`
- Metal library: that app's `Contents/Resources/default.metallib`
- Signed iOS app: `build/highlight-fix/ios/Build/Products/Release-iphoneos/VialsFluidLab.app`
- Latest build logs/regression output: `build/reset-progress/`

Useful targeted scripts in `Scripts/`: `validate_reset_progress.sh`, `validate_glass_antialiasing.sh`, `validate_overlap.sh`, `validate_concurrent.sh`, `validate_progression.sh`, `validate_surface_lifecycle.sh`, `validate_fluid_2d.sh`; `benchmark_seed_setup.sh` and `benchmark_concurrent_3d.sh`. Read each script's arguments first. Generated Original-game tests include `validate_generated_levels.swift`. Do not run every expensive suite for every cosmetic edit; pick checks covering the change and known risks.

Device last used: M4 iPad Pro 13-inch, iPadOS 27. CoreDevice ID `708ACD1F-C8CB-558B-AC94-B6225F02FE7E`; UDID `00008132-001C45281139001C`. Rediscover/verify connection before use. Historical wireless Instruments attempts failed. USB eventually worked with short Game Performance captures requesting 15 seconds and a 12-second rolling window; longer attempts sometimes failed finalization with “Document Missing Template Error.” Reject unusable traces. Raw data is under ignored external-drive `build/overlap-performance/`; `Reports/Prototype11/analyze_render.py` analyzes exported trace data.

Actual Mac UI automation works through **System Events accessibility via osascript**. In the reset test, the app's AX process name was `VialsFluidLab`, and the Board options menu appeared as **More**. Prefer filtering by bundle ID to avoid controlling another running copy. Disposable reset-check bundle: `dev.vials.ResetProgressChecks`, app at `build/reset-progress/VialsResetChecks.app`; it was quit after testing. The test's caffeinate process was also stopped. No requirement to preserve this disposable app.

Keep large builds/traces on the external drive. Run performance measurements without concurrent builds, screenshot capture or other benchmarks. Distinguish actual touch/UI automation, programmatic app trials, offscreen renderer captures, controller intervals, GPU duration, displayed-frame timing and battery evidence in reports.

## Scheduled monitor and permissions

Automation **`watch-vials-ipad-performance` is PAUSED**, verified from `/Users/eddie/.codex/automations/watch-vials-ipad-performance/automation.toml`. Eddie asked to pause scheduled work. A prior automatic approval review rejected reactivation, citing that pause request; do not silently resume it. This monitor is attached to the old chat; a new chat does not automatically own it. Use the automation tool for any user-requested change, preserving quiet notifications unless findings materially change.

The old tool sandbox allowed writes to the original Vials cwd, but **Lab is a sibling directory** and required approved escalated shell calls for edits/builds/UI/device access. Do not interpret that as a reason to work in the wrong checkout. Check the new chat's actual permissions and applicable instructions. No applicable AGENTS.md was found during recent work; recheck if repository instructions change.

A stray uncommitted `xz` before `import Foundation` in `LabBoardRenderer.swift` had blocked compilation during a monitor check. It was removed while building the reset feature; the renderer now matches the committed antialiasing implementation. That blocker is resolved.

## Suggested opening for the next chat

Confirm the current branch/status and read this handoff plus Prototype26/25/24/23. The immediate technical follow-up is optimizing the GPU-bound 22,400-particle Sixfold workload, then repeating the same controlled device profile. Longer unplugged energy testing remains separate. Do not reopen the completed cap-ordering or solver work, restart the project, or describe speculative fluid-rule ideas as already approved work.
