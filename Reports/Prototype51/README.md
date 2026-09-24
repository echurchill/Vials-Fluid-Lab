# Sorting Course 50-level batch — September 24

## Player experience

- Sorting Course now contains 50 fixed levels; the accepted first 25 boards are unchanged.
- Levels 5, 10, 15, and every fifth level through 50 remain Discovery boards with hidden units and persistent discoveries.
- Levels 26–50 extend the hard progression with fixed boards of up to ten vials. The draft 11–12-vial tail was rejected because it made hint search and iPad presentation worse merely to increase the count.
- Endless Sorting remains dynamically generated and is not affected by the frozen course expansion.

## Authoring boundary

- Original's generator remains an offline source only. The shipping app stores literal board data and never invokes Original gameplay, animation, or asynchronous code for Sorting Course.
- The authoring utility now accepts optional course-level arguments and requires every chosen candidate to solve under the shipping Lab model. If the Original-tuned variant exceeds the Lab search budget, it chooses a distinct Lab-solvable variant without weakening the budget.
- The validator also accepts optional level numbers, so replacement candidates can be checked quickly before the complete 50-board gate.

## Validation

- Every frozen board is compared with its recorded source mode, source number, and generation variant.
- Every board has a complete Lab-engine route; the final four routes are 51, 50, 48, and 58 moves.
- Session checks cover the 50-level progress total, navigation, Quick pace, save/relaunch, helper add/upgrade/Undo, helper-required-empty completion, helper-aware hints, concurrent helper reservations, Discovery knowledge, and return to the authored Sorting Lab.
- The final signed build was installed and launched on Eddie's physical iPad with its saved game intact. Landscape and portrait inspection confirm the helper card remains beside the vial summaries and Hint remains unobstructed. Direct add/upgrade/pour/Undo touch acceptance still requires interaction on the iPad; the connected device interface can install, launch, orient, and capture, but cannot synthesize taps.
