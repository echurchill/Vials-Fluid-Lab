# Original-to-Lab consolidation: Endless Sorting — September 22

## Direction and boundary

Original is being consolidated into the Lab, not the reverse. The first slice imports only Original's useful deterministic curriculum data: difficulty, level number, generation variant, vial capacities/rules, and ordered fluid layers.

The Lab remains authoritative for interaction, concurrent pours, Classic/2D/3D presentation, animation clocks, hints, Undo, persistence, learning, diagnostics, and performance. No Original renderer, animation controller, asynchronous workflow, or game-session machinery was adopted. The legacy Original game remains available during the transition as **Original game (legacy)**.

## Changes

- Added **Endless Sorting** to the Lab with Easy, Medium, and Hard generated levels.
- Adapted generated Original boards into exact `LabBoardState` values without changing capacity, rule, pigment, order, or volume.
- Added previous/next-level and difficulty navigation, plus a direct return to the authored Sorting Lab.
- Added Lab-native save/restore for the selected generated board and its progress. Saves retain the exact initial board so later generator tuning cannot silently change an in-progress level.
- Kept Endless progress entirely inside the Lab save. The legacy Original progress and generation-variant stores are not read or written.
- Tuned Endless Quick playback to 2.4×, leaving authored Lab Quick playback at 1.6× and Relaxed playback at 1×. This keeps the Lab engine and choreography while shortening the repetitive sorting cadence.

## Validation

- New `Scripts/validate_endless_sorting.sh`: deterministic adapter equivalence across Easy/Medium/Hard samples; Lab-engine solve and pour; checkpoint/restore; safe return to authored Sorting.
- Existing Journey/Learning suite: 24 solvable, reachable stops; navigation, progress sharing, learning persistence, and legacy migration pass.
- Existing complexity suite: all authored puzzle solvers and save migration pass; the four largest 3D and 2D fixtures, including valve rules, pass.
- Final signed macOS and iOS Release builds pass. The iOS build uses the expected Apple Development identity and provisioning profile; the former missing Xcode token warning no longer appears. The only remaining build warning is the existing AppIntents metadata skip.
- Mac accessibility smoke test confirms the Endless Sorting control and Easy/Medium/Hard choices. The current saved board was not changed.
- `git diff --check` passes.

## Recommended remaining order

1. Add Lab-native background preparation of the next tuned generation variant if measurement shows generation latency warrants it. Do not copy Original's asynchronous controller; use the Lab's task/cancellation model.
2. Decide how Original's Mastery, Flow, score/rating history, and optional helper cup should appear in the Lab. Treat each as a product decision, not automatic parity.
3. Port the fifteen valve experiments as authored Lab lessons, merging or discarding any that duplicate the newer Recovery and Crossover curricula.
4. When migration becomes a release requirement, decide which existing progress and player-result history is worth retaining and add that conversion deliberately.
5. After a release-quality migration window, remove the legacy Original sheet and its runtime-only code. Keep the deterministic generator only if Endless Sorting remains valuable.
