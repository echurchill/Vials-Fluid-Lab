# Original-to-Lab consolidation: Discovery cadence and Lab navigation — September 23

## Product changes

- Moved the fifteen-level Valve course out of the top navigation and into the unified **Labs** menu as **Valve Lab**.
- Retired Discovery as a standalone Lab and Journey branch. Its authored boards remain internal reference fixtures for the hidden-unit engine and validation.
- Promoted Discovery into Endless Sorting: levels 5, 10, 15, and so on use hidden units in Easy, Medium, and Hard.
- Made each Discovery checkpoint explicit in the header, title, board details, instructions, accessibility descriptions, teaching guide, and save identity.
- Redirected a retired standalone Discovery selection to the player's last authored Sorting board (or First sort) so no one launches into an unreachable mode.

## Architecture

- The existing Lab session, save, Undo, hint, concurrent-pour, and Classic/2D/3D presentation paths remain authoritative.
- Endless still uses deterministic runtime generation and stores its exact initial board. The fifth-level profile changes only Lab behavior and initial visibility; it does not adopt the Original game's controller or animation behavior.
- The original five Discovery boards and `LabDiscipline.discovery` remain available to focused engine validators, but `LabDiscipline.availableLabs` is the product-facing catalog.

## Validation

- Endless adapter equivalence still checks capacities, rules, colors, layer order, and volume.
- Easy, Medium, and Hard level 5 all solve under hidden-information rules.
- Journey validation confirms there is no standalone Discovery branch and that retired saved selections redirect to Sorting.
- All fifteen Valve boards still match their frozen catalog and solve under Lab rules.
- Full macOS Debug compilation succeeds.
- Isolated live UI review confirms the revised Labs menu, Valve Lab entry, and the visible Endless Discovery treatment at Easy 5 without touching saved progress.

## Recommended next implementation order

1. Add Lab-native optional helper cups to authored Sorting, Endless, and Valve Lab, including save, Undo, hints, concurrent reservations, and all three presentations.
2. Build offline-generated and solver-validated static catalogs for the main authored Sorting progression, with Discovery checkpoints at every fifth level.
3. Add dedicated catalog-generation profiles for valves and hidden-unit difficulty rather than merely increasing vial counts.
4. Expand the stable catalog in measured batches, then tune difficulty from tester completion and helper-cup usage data.
5. Retire the remaining Original-game sheet only after Lab feature parity and a later save-migration window.
