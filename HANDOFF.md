# Vials Fluid Lab — handoff to the next chat

## September 23: Lab-native helper vessels (Prototype49)

Sorting Lab, Sorting Course and Endless now offer up to two helper vessels. Each starts as a one-unit tea cup and can be upgraded to a two-unit coffee mug and three-unit water jug. Adding/upgrading is saved and Undoable but does not increase the move count; pours do. Helpers use ordinary bidirectional matching-material rules, retain Discovery parcel knowledge, participate in concurrent capacity reservations, and are understood by the solver/hints. Every helper must be empty to win, so a full uniform helper is never a target. Its continued presence in a solved state is the future assistance/mastery signal.

The implementation is entirely in the current Lab model/session/renderers. Original controller/animation/async code was not adopted. Classic, 2D and 3D draw distinct capacity-scaled bodies and handles. Scope is intentionally pure Sorting, Sorting Course and Endless; Valve and target/apparatus labs do not expose the control yet. Focused helper/Sorting validation, all 25 course solutions, the 18-case cross-lab concurrency suite, presentation rendering and final signed macOS/iOS Release builds pass. See `Reports/Prototype49/README.md`.

September 24 follow-up: Eddie found that adding a helper in 3D visually emptied the board until the next pour. The cause was reuse of world-space particle samples after the new vessel changed all home positions. Add/upgrade now reseed the new topology while preserving the old sample solely for Undo. Particle containment checks and fresh three-presentation captures cover add, upgrade and Undo; the corrected 3D capture shows all liquid immediately.

## Future Valve Lab revision: color-keyed lids

Eddie wants the provisional cyan rim line/down-arrow treatment replaced by a physical lid whose color identifies the only pigment a receive-only valve accepts. The lid should remain closed for the wrong pigment, open for a valid incoming pour, and make the rule understandable before any liquid enters. This permits valve vials to start empty instead of relying on preloaded liquid as their color indicator. Use an accompanying pattern/symbol for accessibility. Completion requires a full valve of its keyed pigment; pouring out remains illegal. This is a future work item, not current behavior. It needs explicit accepted-pigment metadata shared by model, solver/hints, saves, concurrent reservations, generation, and Classic/2D/3D rendering. Remove the old marker only after lid readability is validated. The detailed note is in `Reports/progression-curriculum-and-valve-plan.md`.

## September 22: returned-source interaction fix (Prototype43)

Eddie's Buried clue Quick B→D / A→C / B→C reproduction exposed a 3D receiver-group completion lock, plus late streams cancelling an older source's settle. Fixed independent ordered source release, preserved completed settles, deferred starts during an active short correction, and kept the five-percent per-move correction bound. Eddie also reported 2D; independently reproduced its post-touchdown cleanup delay and moved cleanup into the return. Classic completion now matches its existing rendered touchdown (7.2 rather than 7.6 simulation seconds). No geometry/camera/material/path changes.

All 24 new timing/pace/presentation regressions and 18 existing lab/presentation concurrency cases plus density/Discovery/machine checks pass. Both Release builds pass. Live Mac UI with caffeinate verified A becomes enabled while B remains Pouring, then accepts A→D, in 2D and 3D. iPad diagnostic smoke tests committed 14/14 3D and 18/18 2D pours; final build installed and normally relaunched. Exact physical touch reproduction remains for Eddie; do not call these battery/FPS tests. See Reports/Prototype43. Eddie verified the behavior was much better and requested this checkpoint be committed and pushed. Baseline was 6683343; unrelated root PNG untouched and scheduled monitor paused. Testing-only caffeinate was stopped.


September 22 push checkpoint: teaching bridges, learning guides and async GPU warning fix committed and pushed as `7217dd1` on `codex/fluid-lab`. Earlier local/unpushed notes below describe prior checkpoints. Remaining UI checks are unchanged.

## September 22 checkpoint: GPU warning fixed; Mac checks resumed

User reconnected iPad and reported Xcode's async `waitUntilCompleted()` warning. Changed only that optional profiler call to `await command.completed()`; both Mac/iOS builds pass with the reported warning removed. Latest signed build installed/launched on the M4 iPad. Mac live first-use guides, paging, dismissal, replay, Ready to blend completion/Next, and One step heavier completion/Next passed. Full iPad visual acceptance remains pending; QuickTime has a file picker, no preview/recording. See Prototype42 follow-up for remaining checks. The earlier locked-Mac/iPad-unavailable notes below are historical. Caffeinate used during checks, stopped afterward. Changes are still local/unpushed; preserve unrelated root PNG.

## Latest: teaching bridges and first-use guides (September 21, Prototype42)

User asked for progression improvements first, then contextual introductions. Added Ready to blend, One step heavier and Float again before Equal partners in Crossover; both Density and Recovery enter this short bridge sequence. Added Third color before Hidden garden in Discovery and included existing Room for both in Journey Recovery. Journey now has 24 stops (four new puzzles, one previously omitted existing puzzle). Existing starts/identifiers are unchanged; direct-lab numbering includes the inserted lessons.

Added a Learning guide (?) button beside board options. Six topic types open once on fresh encounters, can be paged/dismissed, and can always be replayed when relevant. Core tool explanations also appear in existing machine information popovers. Seen identifiers are backward-compatibly saved/shared across labs and Journey; full reset clears them, ordinary reset does not. Diagnostic trials suppress automatic teaching. UI presentation waits for navigation dismissal and avoids busy, selected, hinted or partially played boards. Guides participate in scene suspension without changing player pause state.

Graph (24 stops), guide persistence/migration/replay/reset tests and all 22 experimental session routes pass. Wide/compact maps and all six guide renders inspected. Final Mac and signed iOS Release builds passed, including the introduction guard refinement; logs are /tmp/vials-learning-mac.log and /tmp/vials-learning-ios.log. Live UI blocked: Mac is locked, automatic unlock failed, and an async unlock question is pending. Caffeinate was used for the test attempt and stopped afterward; restart it when resuming UI checks. It cannot unlock the Mac. No iPad access (still unavailable). Finish live checks: open a new bridge from Journey, page/dismiss first-use tips, solve to Next, return without repeat, replay via ?, enter Discovery and inspect its guide. Preserve physics/vial visuals; none of their source files changed. These changes are local/uncommitted, not pushed; latest remote remains 24380e8. Unrelated root PNG untouched; scheduled monitor paused.

## Latest: Journey implemented and Mac interactions verified (September 21)

User approved a Journey entry and branching learning map. Added 19 curated existing teaching stops with learning goals, completion/current markers, open access, shared lab progress, cross-lab Next, fork choice and path-ending map action. Sorting branches to Density/Mixing/optional Discovery; Mixing → Recovery; Density/Recovery → Crossover. No new puzzle layouts or physics changes. New saves/fresh reset enter Journey; old saves stay in direct labs. Explore labs exits Journey; selecting a map stop resumes the existing board.

Both final builds, new graph/navigation/save tests and existing 19 experimental session routes pass. Wide/compact offscreen map renders inspected. Live Mac checks with caffeinate passed: map scrolling/selection/close, Second chance → Equal partners, same-lab exit, seven-pour Cross currents fork → optional Discovery, and 11-operation Full spectrum → terminal Journey map. All three presentations were exercised. Explicit button accessibility traits were added and verified after rebuild/relaunch. Mac screenshots remain undersized/distorted, so full-resolution live visual acceptance is not claimed. iPad was unavailable during this follow-up and was not accessed; portrait/landscape review and installing the final accessibility-only correction remain pending. Reports/Prototype41 contains evidence/limitations. Machine guidance checkpoint 505b0dd was already pushed; Journey is the accompanying commit. Scheduled monitor stays paused; unrelated root PNG untouched.


## Latest: machine connection guidance (September 21)

User requested checkpoint push, then clearer machine connections. Prototype37–39 were committed/pushed as 761328d37c390156812d33a3de51c6a9bf148437; remote verified. New Prototype40 is local/unpushed: machine information, machine hints and active operations highlight their inputs/outputs, matching footer cards and role badges. Dashed lavender inputs, solid outputs and directional curves below the vessels. Shared ports highlight the relevant machine role. Density highlights its chamber only.

A popover can cover a port on iPad, so Show connections closes it and leaves the route for four seconds; next selection/operation/hint or level change clears that preview. Reduced Motion removes the fade. User specifically asked whether pour animations were being removed: NO. All lift/tilt/flow/return, simulation, camera and vessel geometry remain unchanged. Final builds and Mac guide/hint/action/expiry/ordinary-pour checks pass. iPad final build installed; landscape guidance visually checked via QuickTime (View → Float on Top fixed tiny screenshots). Device Hub input still times out. No recording, no new battery claim, no portrait/touch-forwarding acceptance. See Reports/Prototype40.

The isolated diagnostic flag `--lab-trial --visual-review --inspect-machine <id>` opens the chosen guide. Return the app to normal launch afterward. Scheduled monitor remains paused; keep unrelated root PNG untouched. Caffeinate used during UI checks.


## Latest: role-based vessel silhouettes (September 21)

Eddie approved consistent shapes across all presentations: ordinary sources/storage/final targets use tubes; mixer and Recovery ports use round bulb flasks; density chambers use flat-bottomed tapered flasks. Pear remains implemented but unused, reserved for a future lab. Final targets override tool shapes; density overrides other non-target tool roles. All shared-role badges remain. Profiles derive from fixed metadata, with the exact existing knots, height/radial scaling and depth preserved. Renderer cache now invalidates when shapes change even if capacities match.

Mac/signed iOS builds, 39-board shape/parity/cache assertions, presentation routes, 18 lab concurrency cases, 69 animated machine cases, Sorting concurrency and density trajectories all pass. Updated build installed on iPad; QuickTime landscape inspection confirms all three presentations. See Reports/Prototype39 for evidence and device-trial results. Work remains local/unpushed alongside Prototype37/38; unrelated root PNG untouched. Scheduled monitor stays paused. Use caffeinate during UI checks.


## Latest: iPad concurrency checks complete (September 21)

Final signed build installed on the connected/unlocked M4 iPad. Device Hub AX timed out, but QuickTime's Screen → Eddie’s iPad Pro preview worked after zooming its window. Five live trials: Density in Classic/2D/3D plus Discovery in 2D/3D. 56/56 measured pours committed, including shared receivers; no rejected/stuck pours; max cleanup 2.61%; all thermal samples nominal. All 21 Density control checks passed. These were short charging/screen-sharing runs, not battery or compositor-FPS measurements. Reports/Prototype38 contains JSON and limitations. No further code changes needed. iPad relaunched normally at Crossover → Twin products → 2D Fluid / Quick, 3 existing moves; QuickTime preview remains open. Mac stays at completed First reveal / 2D / Relaxed. Caffeinate was used during checks. Work is still local/unpushed; scheduled monitor remains paused.

## Latest: concurrent pours in every lab (September 21)

Eddie authorized extending Sorting-style concurrency. All six labs now allow overlapping ordinary pours, including shared receivers (two active approach lanes; additional accepted pours queue). Machine transitions remain globally exclusive. Density uses multi-stream joined-volume bands and stable reservation order for equal-density arrivals; Discovery fades are per-source and allow unrelated pours to continue. A small-vial 2D lip-guide adjustment prevents a rejected near-miss without expanding the 5% cleanup allowance. Vial shapes, sizes, camera and layout definitions are unchanged. See Reports/Prototype38 and Scripts/validate_lab_concurrency.sh.

All 18 lab/presentation matrix cases plus density ordering/descent, Discovery overlap/pause, machine guards, save/Undo/Reset pass. Existing Sorting concurrency, 19 experimental session routes and density trajectories pass. Live Mac UI checks were done with caffeinate; physical-iPad acceptance/performance remain pending. These changes and Prototype37 remain local/unpushed against 59f44e9. Keep the unrelated root PNG untouched and the scheduled performance monitor paused. Future independent machine concurrency is not included in this pass. Final Mac and signed iOS builds pass. Final-build live Relaxed 2D Discovery retry and two concurrent completion pours passed, including caps and Next; Mac is left at completed First reveal / 2D Fluid.

## Latest: shared machine-role labels (September 21)

Recovery level 3 D is a separator output AND mixer input. Eddie noticed only SEP OUT was shown. Fixed the first-match lookup to return all associated tools; shared badges stack upward without moving/resizing the vial. Accessibility names both roles, and mixer result previews name input letters. Mac visual checks pass in Classic/2D/3D and both builds pass. The Mac is now on Recovery → Second chance → 3D Fluid. Still local/unpushed; no iPad install. See the Prototype37 addendum.


## Latest: machine guidance → Recovery → Discovery (September 20 overnight)

Eddie authorized all three stages after the level-tree picture and explicitly asked to preserve the vial visuals. Implemented local, unpushed changes: anchored machine requirement/result popovers (ready buttons still activate in one tap); four Recovery levels with a conserved-volume two-output separator; four Discovery levels with neutral unknown portions, knowledge-aware exploratory hints, known-batch pour boundaries, stationary pause-aware reveals, and discoveries retained through Undo/Reset/save. All six labs are selectable; no unlock tree was implemented. See Reports/Prototype37/README.md for the exact scope and morning review route.

All 39 model fixtures, 19 experimental session routes, 69 animated machine cases, 12 complete Discovery routes/cases across Classic/2D/3D and the existing small-vial presentation gate pass. Mac and signed iOS Release builds pass. Existing profiles, sizing, depth and camera parameters were preserved. Live Mac UI checks and selected rendered frames were inspected; do not equate those with user approval or physical-iPad acceptance. Eddie said the iPad is unavailable overnight; no overnight install/profile was attempted. Caffeinate was used for Mac UI automation. New work remains local against pushed baseline 59f44e9. The final Mac app is running normally (no trial flags) at Recovery → Split purple → 3D Fluid for morning review. An unrelated untracked root image, ChatGPT Image Sep 20, 2026, 06_59_07 PM.png, appeared during the work and was left untouched.

The earlier notes saying Discovery is documentation-only are superseded for this Sorting-only prototype. Hidden pigments in Density/Mixing/Crossover and broader campaign combinations are still future work. Sound remains deferred and the scheduled performance monitor stays paused.


## Latest: iPad portrait/landscape review complete (September 20)

QuickTime now works: open New Movie Recording, then select **Screen → Eddie’s iPad Pro** (the iPad is under Screen, not Camera on this OS). No reboot was needed. CUA live-preview inspection passed Shades of blue in Classic/2D/3D in landscape and portrait, plus ten-vial Twin products in 2D landscape and all three modes in portrait. Density symbols are distinguishable; targets, legend and controls fit without clipping. 3D symbols are softer than 2D but recognizable. This was passive visual inspection, not a new touch-latency test. See Reports/Prototype36/README.md. Prior visual-blocker notes below are superseded; GPU comparison and the 12-case live density-control diagnostic were already complete and were not repeated.

Found and fixed an initial/restored-launch instruction bug: experimental labs now show “Match the outlined target vials” instead of Sorting’s matching-color instruction. Added an assertion across all 15 experimental session routes; validation plus Mac/signed iOS Release builds pass. Installed and visually verified the fix on iPad. No vial geometry, framing or rendering changes. Guidance/profile/design work is pushed as d7a8875; this later text fix, test and review documentation form the subsequent publication checkpoint requested by Eddie. Use the Git log and remote head for its publication status.

The obscured-fluid proposal remains documentation only. Sound and new physics mechanics remain deferred; the scheduled performance monitor remains paused. For future UI testing, use caffeinate on the Mac and the working QuickTime live preview. Do not repeat the completed GPU profile without a rendering change or new concern.


## September 20 guidance and design checkpoint

This checkpoint includes the density legend, target-mismatch explanations, corresponding model/session tests, completed physical-iPad surface comparison and diagnostic results, and the future obscured-fluids design proposal. Earlier local/uncommitted status notes for those changes are historical; use the Git log and remote head for publication status. Direct physical-iPad visual acceptance remains pending because QuickTime/Device Hub automation times out; no reboot or app termination was performed as part of investigating that issue.


## Future design addition: obscured fluids (September 20)

Eddie supplied examples of hidden lower fluid portions that become identifiable as upper material is poured away. Added an optional Sorting-first discovery experiment to `Reports/fluid-logic-laboratory-design.md`, section “Future Experiment: Obscured Fluids.” It also explores visible-density/hidden-pigment puzzles and later identification tools for Mixing/Crossover. Fixed hidden identities, retained discoveries, free Undo, knowledge-aware hints and avoiding visual/accessibility leaks are central. Documentation only; no implementation authorization or game-code changes for this idea. The existing guidance implementation and pending iPad visual review remain as described below.


## Latest: density guide, target explanations and iPad GPU comparison (September 20)

Eddie authorized recommendation 3 (guidance), then 1 (iPad visuals) and 2 (GPU cost). Shared UI now has Light/Medium/Heavy swatch legend + info popover; target cards explain quantity, color, order and density mismatches. Committed target pours and selecting a target show the full explanation, also in VoiceOver. Fill-only targets can be inspected without becoming sources. Fixed status/notice heights avoid completion-driven layout jumps. Model and session checks pass, and live Mac mismatch feedback/guide/view switching were exercised.

A physical M4 iPad baseline/current/current/baseline GPU comparison passed on frozen identical 6-/10-vial density scenes and Sixfold at 720×432/1000×600. All thermal states nominal. Density-scene median GPU deltas are −0.2% to +1.0% (about 0.02 ms or less); no material surface regression. It is offscreen command-buffer timing, not displayed FPS or battery evidence. New opt-in flag: `--lab-trial --profile-density-surface --keep-awake`. Baseline 083d383 lives in ignored build/density-surface-baseline with identical harness. See Reports/Prototype36 for raw results and exact limitations.

Direct iPad visual acceptance is still pending because Device Hub/QuickTime CUA time out. Asked Eddie to open QuickTime → New Movie Recording and choose iPad as camera; no reply yet. Mac screenshots also came back as tiny previews, so do not claim a full pixel-level layout review. Both final builds pass. The guidance build passed all 12 live iPad density-control cases; the final compact legend/control layout is built, installed and launched normally on iPad. These changes are local/uncommitted; last pushed commit is f612b33. Finish physical visual review when the preview is available; do not repeat the completed GPU work merely because the visual check remains open.


## September 20 density checkpoint

This checkpoint includes the density-apparatus animation, hue-independent triangle motifs, larger matching contents/target symbols, directional fades, and the 12-case physical-iPad diagnostic/results. Earlier notes describing these changes as uncommitted or unapproved are historical. Use `git log` and the remote branch to resolve publication status.

Next priorities: complete visual acceptance on the iPad (light/heavy readability, small vessels and dense target cards, portrait/landscape); measure the added 3D density attachment with a controlled before/after device profile; then improve density onboarding with a compact symbol legend and clearer target-mismatch feedback. These are recommendations, not authorization to implement all of them. Sound and new physics mechanics remain deferred.


## Latest: physical iPad density checks (September 20)

The signed current build is installed on Eddie's M4 iPad Pro. All 12 live-clock density-control cases pass across Classic/2D/3D, covering Light→Medium, Medium→Heavy, Medium→Light, Reduced Motion, pause/resume, single commit, inventory, renderer errors, Undo and Reset cancellation. New diagnostic flag: `--lab-trial --check-density-controls --keep-awake`; it is isolated from saved progress. Results: `Reports/Prototype35/ipad-density-controls.json`. Both builds pass. Actual iPad visual inspection remains pending because Device Hub/QuickTime CUA repeatedly timed out despite an unlocked Mac; Xcode/Mac-game access worked. This is functional evidence only, not GPU/battery measurement. App relaunched normally afterward. Changes remain local/uncommitted; latest pushed checkpoint remains `083d383`.


## Latest: density symbols and directional fade (September 20)

The tiny L/M/H contents/target labels have been replaced by shared 14-point swatches: pale up-triangle for Light, plain Medium, dark down-triangle for Heavy. Target and contents now use matching full pigment color; spoken density descriptions remain. Eddie then requested directional entry animation: density motifs fade in while drifting up for Light/down for Heavy, easing to their stationary positions. Outgoing motifs drift the same way while fading out. Classic/2D/3D share the pause-aware transformation clock; Reduced Motion keeps the fade only. Mac and signed iOS builds plus all 18 focused density-animation cases pass. Intermediate visual fixtures inspected; live Mac 2D/3D pause/resume/completion checked with caffeinate. No iPad test. See Report35. All changes since pushed checkpoint `083d383` remain local/uncommitted.


## Latest: density triangle prototype (September 20)

Eddie approved prototyping shape-based density. Classic/2D/3D now retain base pigment hue at every density and use pale upward triangles for light, plain medium, dark downward triangles for heavy. Apparatus transitions crossfade patterns; cap/card hue also uses base pigment. Layer metadata and puzzle rules remain unchanged. 2D density decoration is quieter; 3D uses an rg16Float density-weight attachment in the existing surface pass and antialiased vial-local motifs. No preference toggle. See `Reports/Prototype35/README.md` and `Scripts/preview_density_patterns.sh`.

Mac/iOS builds, 12 visual fixtures, 18 density-animation cases, 48 mixing cases and seven density-pour cases in both particle modes passed. Mac 3D activation/pause/resume/undo succeeded; 2D activation/pause exercised, then UI capture errors/interruptions prevented the final sequence and level switch. Prototype is loaded in the Mac app; review via Density → Shades of blue. No iPad test/profile yet. All density-animation and triangle work remains local/uncommitted; pushed checkpoint is still `083d383`. The older note saying triangles are unapproved is historical and superseded.


## Latest: density apparatus animation (September 20)

Mixing and corrected shadows are committed/pushed as `083d383`; remote hash verified. The subsequent Make heavier/Make lighter animation is implemented locally across all three views, with a shared LabApparatusTransition, gradual tint change and gentle internal downward/upward motion. The uniform chamber retains its volume and particles, with no final repack. All 18 authored density cases and 48 mixing cases pass; Mac and signed iOS builds pass. Offscreen renders inspected. Live Mac activation check remains incomplete because CUA screen capture failed with -3811 after the setup pour; no iPad test. See `Reports/Prototype34/README.md`. These density changes are uncommitted/unpushed.

Eddie is considering density triangles (pale upward for light, dark downward for heavy) to keep hue dedicated to pigment and improve accessibility. Discussed but not implemented or explicitly approved. Suggested sparse, readable symbols with modest size variation and plain medium liquid. Preserve this as a future design item.


## September 20: checkpoint pushed; visible mixing prototype ready

Checkpoint `9c86721` is pushed to `origin/codex/fluid-lab` and verified against GitHub. The subsequent local mixing prototype adds pumped input transfer, a vortex and gradual recipe-color blending in Classic/2D/3D. Activation commits exactly once after the pause-aware transition; reset cancels it, undo restores inputs, and checkpoints retain the pre-mix board. Density modifiers stay immediate. All 48 authored animated mixer cases pass, plus post-mix pours for the introductory recipes, and all three modes passed live Mac mixing/pause/resume/undo checks. Mac and signed iOS Release builds pass. iPad hardware is unavailable; no performance claim. See `Reports/Prototype33/README.md` and `Scripts/validate_mixing.sh`. Mixing changes remain uncommitted/unpushed for review.

## Latest: final-level completion control

Final levels now show a clear “Final level complete” notice and a prominent “Choose level” menu in the reserved bottom toolbar slot. This applies to all four labs and three presentations; earlier levels retain Next. Actual Mac Full spectrum completion, unchanged layout, menu contents and navigation pass in Classic/2D/3D. Mac and signed iOS builds pass; no iPad install. See `Reports/Prototype32/final-level-completion.md`. Changes remain local and uncommitted.

## Latest: density settles during the pour

Medium/heavy arrivals now descend through lighter layers during the pour in Classic, 2D and 3D for Density and Crossover. Existing equal-density liquid stays underneath the arrival (even with a different pigment). Joined particle volume progressively shifts lighter bands upward; 3D uses bounded descent and its existing thickness pass to reveal the submerged plume. Exact game ordering and the 5% correction allowance are unchanged. Seven trajectory cases pass in both particle modes; all ten Density/Crossover routes solve and fully undo in both. All three modes pass live Mac Heavy landing UI checks with caffeinate, and Mac/iOS Release builds pass. Physical iPad validation remains pending; local changes remain uncommitted/unpushed. See `Reports/Prototype32/README.md` and `Scripts/validate_density_pour.sh`.

## Latest UI adjustment: Next Level button

The shared Next Level button moved below the info text into the bottom toolbar between Hint and Pause, across all four labs and all three presentations. Its reserved invisible slot prevents completion from changing the board height. Actual Mac UI before/after position checks pass in Classic, 2D and 3D; navigation and accessibility visibility also pass. Both builds succeed. See `Reports/Prototype31/next-level-button.md`. This edit remains local and uncommitted.

## September 19 round-vial recovery — current status

Eddie approved replacing the rejected flattened-vial workaround after reviewing its postmortem. Capacity now changes height and width together, preserving round cross-sections and equal unit volume; one-unit vessels are 50% as tall and 71% as wide as four-unit vessels. 2D uses the common volume-to-height projection, and 3D marks actual capacities 1–6. The old 85/90/95/100% heights and depth compression are gone.

The first revised 2D projection exposed a 7.63% low fill in Tall Order. Matching bulk particle spacing to the projected local volume fixes it: all 175 expanded 2D pours pass without loosening fill, activation or cleanup checks. The flattening-specific capture/collision changes reproduced a shared-receiver failure even with the starting profiles. Removing those changes restores passing full concurrent and overlap regressions. Mac UI checks include a real A→D pour, pause/resume, presentation switching and reset. Builds pass; iPad validation is pending availability. This is a candidate for Eddie's visual review, not a claim of final visual acceptance. See `Reports/Prototype31/README.md` for comparisons, exact test scope and limitations. The Density starting-board corrections below are retained separately. Recovery changes have not been committed or pushed.

## September 19 Density starting-board correction — latest status

- All five Density Lab initial boards now obey their own heavy-to-light settlement rule. Levels 1–3 introduce separate one-unit samples in ordinary-capacity vials; level 4 groups heavy material and a stable medium/light stack; level 5 groups Heavy at A, Medium at B, and Light at E around the two targets at C/D, matching the tester's suggested distribution.
- Authored routes and initial-hint expectations were updated. A selective versioned save migration discards old Density checkpoints that contain the impossible starting arrangements while preserving Sorting, Mixing, and Crossover progress.
- The keystone model/session suites pass, including a new invariant for settled Density/Crossover starts and the migration check. Mac 3D Fluid screenshots were visually inspected for the first and final Density levels. See the September 19 addendum in `Reports/Prototype30/README.md`.

## September 18 keystone laboratory prototype — latest status

- The shared Fluid Lab app now has four independent disciplines: the established 16-level Sorting Lab plus five-level Density, Mixing, and Crossover labs. The four-way selector is independent of Classic / 2D Fluid / 3D Fluid and Relaxed / Quick; each lab remembers its most recent level.
- Materials now carry pigment plus Light/Medium/Heavy density. Density and Crossover levels accept unlike materials and settle them heavy-to-light. Pastel/normal/dark rendering and explicit L/M/H labels are shared across all three presentations.
- Experimental completion uses exact bottom-to-top targets on actual board vials and ignores harmless surplus elsewhere. Mixing consumes fixed one-unit primary inputs and emits two secondary-color units. Density modifiers transform a whole homogeneous batch one step. Apparatus operations participate in hints, Undo, persistence, and the operation solver.
- Fifteen authored experimental levels are playable: five Density, five Mixing, and five Crossover. Every authored route passes model and production-session validation, including initial hints, Classic commits, apparatus activation, completion, full Undo, lab switching, and persistence. Existing saves migrate to medium density.
- Sorting retains dependency-safe three-or-more simultaneous pours. Experimental labs deliberately serialize operations for deterministic density settlement and apparatus input order during this prototype.
- All 16 legacy Sorting levels still solve and retain their capacity/valve behavior. A full macOS Debug build, including Metal, succeeds without warnings. Native visual inspection was unavailable at the end because the Mac session was locked; physical iOS validation was intentionally deferred under the approved macOS-first plan.
- See `Reports/Prototype30/README.md` for implementation details, the suggested review path, remaining experience questions, and exact validation scope. The prototype implements `Reports/keystone-lab-prototype-plan.md`, which is associated with `Reports/3d-fluid-simulation-plan.md` and `Reports/fluid-logic-laboratory-design.md`.

## September 18 bounded multi-lane physics — latest status

- Stage-specific physical-iPad counters show the full 22,400-particle visible surface is inexpensive (1.33 ms median / 2.71 ms p95 in the matched baseline); compact receiver-lane physics caused the remaining 77 ms p95.
- Independent receiver lanes now share bounded catch-up work. With two or more active receiver groups, each lane performs at most four fixed 120 Hz steps per callback and uses the established three-pressure-projection profile. One active receiver group retains the original 12-step allowance and five projections, including when two sources share that receiver. Visible particle density, normal 60 Hz Quick cadence, authored motion timing and exact final states are unchanged.
- A matched physical M4 iPad Sixfold trial committed the same six pours with the same 22,400 visible particles and 12,160 maximum lane particles. Median GPU time changed 13.46→12.23 ms; p95 fell 78.18→22.91 ms; maximum fell 120.43→30.94 ms; p95 callback interval fell 84.62→25.59 ms; intervals over 25 ms fell 77→31. Both runs remained thermally nominal.
- An occupied-cell grid-clear experiment produced no meaningful iPad improvement and was reverted.
- Full validation passes all 16 model solutions, all 175 expanded 3D routes, all 175 expanded 2D routes, all 18 overlap fixtures and the complete concurrent presentation matrix. Signed iOS Release succeeds and the measured build is installed on the iPad.
- See `Reports/Prototype29/README.md`. Current branch is `codex/fluid-lab`; inspect Git status/log for the final commit/push state.

## September 18 physical acceptance and compact-lane optimization — latest status

- The current signed Release build is installed on the physical 13-inch M4 iPad Pro. Direct device captures verify completed G retains visible headspace beneath its cap, the redundant in-glass valve glyph is absent, A's three retained units travel inside the raised glass during A→C return, and the Classic stream reaches the receiver's accumulating surface. See `Reports/Prototype28/README.md`.
- Concurrent 3D receiver engines now simulate only particles belonging to their participating source/destination vessels. The complete visible board remains at 640 particles per unit; visual density, timing, volume and canonical final states are unchanged.
- The exact Level 16 B+C→G lane is asserted at 3,200 particles (five participating units) instead of 22,400. The complete concurrency suite still passes the 21-frame settle, 34-frame stable return, 0.20-unit headspace and partial-source containment checks.
- A matched 30-second Sixfold / Quick / 3D physical-iPad trial committed six pours before and after. Median Metal GPU time fell 43.09→13.42 ms, median controller/GPU-wait time 16.95→12.84 ms, and intervals over 25 ms 144→82. The optimized run's busiest active lanes totaled 12,160 particles while the visible board remained 22,400 particles. Both runs remained thermally nominal.
- The full expanded-level validation passes all 16 model solutions, all 175 3D routes, all 175 2D routes, all 18 overlap fixtures and the complete Classic/2D/3D concurrency matrix. Signed iOS Release succeeds. Remaining high-percentile spikes (78.02 ms p95 GPU in the short matched trial) make full-board surface reconstruction/worst-case multi-lane frames the next measured performance target.
- Current branch is `codex/fluid-lab`; inspect Git status and the latest log for the exact commit/push state.

## September 18 stream endpoint and completed-vial headspace follow-up — superseded by the physical acceptance above

- The tester's 15-second physical-iPad recording was inspected frame by frame around 11–13 seconds. G's particles were already stable while B/C returned; the apparent final fill was the opaque matching cap visually bridging the small air gap, compounded by measuring particle centers rather than the top of their rendered billboards.
- The 3D particle fill calibration now reserves one rendered particle radius below the shared fill line, so the visible particle surface—not merely its centers—lands at the same naturally headspaced level as Classic/2D. Completion caps remain fully outside the vessel cavity and use a neutral dark underside/gasket, preserving an obvious air gap even when cap and fluid colors match.
- Classic pour streams now extend inside the receiver to its live accumulated fluid surface. The endpoint includes every concurrent incoming and outgoing pour's progress and is clamped to the receiver capacity.
- Removed the redundant cyan fill-only glyph drawn inside 3D vessels. Receive-only vials retain the clearer `↓ FILL` badge above the vessel and the compact rule arrow in the information row; their glass now uses the same neutral volume graduations as other vials.
- A second tester recording exposed the complementary partial-source case after B→G, C→G, then A→C. The receiver-first settle was placing A's three retained units at A's home coordinates while its empty glass was still raised, so the descending glass appeared to reveal liquid already waiting below. Canonical settling now occurs in each vessel's live pose, and retained source particles are carried rigidly with the upright glass throughout return. The exact regression holds all retained particles inside A for 34 return frames with under 0.001 local drift while completed C remains position-stable.
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

September 20 follow-up: contact shadows now shrink/fade with actual vial lift and follow the floor projection in Classic, 2D and 3D (including standalone study). Per-vial Metal samples replace fixed shadows. Mac/iOS builds and offscreen rendering passed; see Prototype33 report. Local, uncommitted; no iPad hardware validation.

Shadow follow-up: user could not see the initial shadows. Increased footprint/contrast, decoupled most opacity loss from shrink, and moved Metal shadow attenuation after the background vignette (critical for outer vials). Corrected previews visibly show dark resting and lifted shadows.

Latest readability follow-up: tiny density letters in current-content and target strips are replaced by LabDensitySwatch triangles, matching fluid motifs. Light points up, Heavy down, Medium plain; strips are 14 pt high and targets use the same full pigment hue plus outline. Mac live Equal partners screenshot confirms G's heavy-content vs medium-target mismatch is visible. Component previews and builds passed; see Prototype35. Local/uncommitted, no iPad check.
