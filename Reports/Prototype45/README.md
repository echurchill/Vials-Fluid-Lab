# Original-to-Lab consolidation: Valve Course — September 23

## Direction

The Original game's fifteen receive-only experiments now form a **Valve Course** inside Sorting. The course uses Original only as deterministic curriculum data. The Lab remains authoritative for legal moves, solver keys, hints, Undo, saves, concurrency, accessibility and Classic/2D/3D presentation.

No Original view, animation controller, asynchronous workflow or game-session state was adopted.

## Changes

- Added all fifteen Original valve boards as a numbered Sorting sub-course and froze the accepted outputs into a stable catalog. Opening a course level does not run the Original generator or solver on the main actor.
- Preserved every board's exact capacities, receive-only rules, colors, layer order and volume.
- Added previous/next and direct level navigation, completion marks, course progress, and a return to the authored Sorting Lab.
- Added Lab-native save/restore for the selected Valve Course board and its progress. The exact initial board is retained in the save so later generator tuning cannot silently alter an in-progress level.
- Added a first-use valve guide explaining that cyan-arrow vials can receive liquid but cannot pour it back out.
- Kept Valve Course Quick pacing at the authored Lab's 1.6×. The 2.4× adjustment remains specific to Endless Sorting.
- Updated Reset all progress to include Valve Course progress.

## Validation

- `Scripts/validate_valve_course.sh` compares all fifteen adapted boards with the Original curriculum and verifies capacities, rules, colors, layer order and volume.
- All fifteen boards solve under the Lab solver and completion rules.
- Session coverage verifies a real Lab-engine pour, teaching metadata, checkpoint/restore, exclusive switching between Valve Course and Endless, return to the authored Lab, and preservation of course progress.
- Existing Endless Sorting coverage remains required to guard the neighboring sub-course and its separate pacing.
- A live Mac accessibility check confirms the Valve Course control, instant Level 1 opening, course metadata, disabled receive-only source, and replayable valve guide. The prior board selection was restored after the check.
- Signed macOS and iOS Release builds pass with the expected development identity and iOS provisioning profile. The existing AppIntents metadata skip remains the only build warning.

## Recommended next slices

1. **Helper cups.** Add a Lab-native optional helper vessel, beginning with Sorting, Endless and Valve Course. Treat it as temporary workspace with full save, Undo, hints, concurrent-pour reservation and three-presentation support. Do not copy Original's view/controller implementation. Decide separately whether authored teaching puzzles should allow it.
2. **Expanded curriculum architecture.** Use a hybrid model:
   - Keep a smaller authored teaching spine for concepts and Journey.
   - Build large deterministic catalogs offline from the generators, validate every board, and ship the accepted results as stable progression levels.
   - Keep runtime deterministic generation for Endless play, where variation is the feature and the exact initial board is already stored with progress.
   - Extend generation with explicit profiles for hidden-unit Discovery and receive-only Valve boards instead of trying to make one generic generator cover every rule.
3. **Tester-facing progression.** Once the expanded catalogs exist, decide whether completion, best moves and optional mastery belong at the individual-level, course or difficulty level.
4. Continue deferring legacy save migration until it becomes a release requirement.

This hybrid avoids hand-authoring hundreds of boards while still preventing an untested runtime generator from defining the main learning progression.
