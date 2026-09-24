# Sorting Course 50-level batch — September 24

## Course 45 Metal upload follow-up

- Course 45 contains 47 parcels across 10 vessels. Its vessel-by-parcel constraint table is 7,520 bytes, exceeding Metal's 4 KB `setBytes` limit when a 3D pour starts.
- The renderer now supplies variable-size vessel and layer tables through command-retained Metal buffers. Small fixed uniforms remain inline.
- The regression uses the actual Course 45 state and encodes both legal F→I and F→J pours, preserving an explicit greater-than-4-KB assertion.
- The focused GPU presentation validation and macOS Debug build pass.

## Portrait layout and valve-lid follow-up

- Classic, 2D and 3D now use two balanced rows when a portrait board contains eight or more vessels. Smaller portrait boards and all landscape boards stay in one row.
- Rendering, input hit areas, camera framing, footer cards and animation homes share the same row calculation. Cross-row pours use a clearance above the tallest upper-row vessel.
- Valve lids in Classic and 2D now have the same substantial projected stopper depth as completed-vial lids; 3D already uses the full cap mesh.
- Static captures were inspected for 12-vessel helper boards and empty keyed valves in all three presentations. Automated checks also exercised the 7/8-vial breakpoint, bidirectional travel clearance and an actual cross-row 2D pour.
- The final signed Release build was installed and launched on Eddie's physical iPad. Active code signing succeeds despite warnings from stale inactive Xcode account records.

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
