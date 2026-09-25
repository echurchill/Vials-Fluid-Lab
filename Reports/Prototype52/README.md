# 100-level Sorting Course and assistance history — September 25

## Player experience

- Sorting Course now contains 100 fixed, validated levels. The accepted first 50 boards are unchanged; levels 51–100 continue the hard progression without exceeding the established ten-vial presentation ceiling.
- Every fifth level remains a Discovery level, including 55 through 100. Endless Sorting remains dynamically generated and independent of the fixed course.
- Completing a board now records whether that attempt used a hint, a helper, both, or neither. The completion message reports that fact neutrally; hints and helpers carry no penalty and do not change the win rules.
- Completion history survives reset and replay. A replay starts a fresh assistance record while retaining the fact that the board was previously completed and the best move count.
- Valve Lab guidance is now progressive: the first board explains the empty keyed valve, later boards emphasize irreversible routing, twin keyed lids, and the interaction between lid colors and vessel sizes. Board details name the actual lid keys.

## Authoring boundary

- Levels 51–100 are literal shipping Lab boards selected from disjoint offline Original-generator variants, then solved under the shipping Lab rules. The running app does not invoke Original gameplay, animation, concurrency, or generation code.
- The offline generator records source mode, source level, and variant for reproduction. The validator checks those records and solves all 100 frozen boards before they are accepted.

## Validation

- All 100 Sorting Course boards match their recorded sources and solve in the Lab engine. Every fifth board through 100 has persistent Discovery knowledge.
- Session coverage includes navigation, completion counts, save/relaunch, reset/replay, hints, helper add/upgrade/Undo, helper-required-empty wins, and neutral assistance records.
- Endless deterministic generation and fifth-level Discovery cadence pass unchanged.
- All 15 Valve Lab boards solve, and progressive lid guidance plus actual key names are covered.
- Reset/relaunch checks pass in Classic, 2D Fluid and 3D Fluid without disturbing Original-game stores or player preferences.
- The complete vessel presentation suite passes, including portrait two-row travel, Course 45's greater-than-4-KB Metal table, the seven-move reproduction, eight-unit D pours, and all small-capacity routes.
- The unsigned macOS Debug build and signed physical-iPad Debug build pass. The final build was installed and launched on Eddie's connected M4 iPad with its existing app data preserved.
