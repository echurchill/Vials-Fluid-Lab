# Fast helper reflow and Journey acceptance

Adding an empty helper now preserves each settled liquid particle's local position and translates it to the new vessel layout. The 2D path no longer reruns 240 whole-board settling steps. The 3D path reuses every unchanged vessel mesh and canonical seed, creates only the new helper geometry, and installs the translated particle sample directly. Portrait one-row/two-row changes use the same translation. Shape-changing helper upgrades deliberately retain the full rebuild.

On Sorting Course 45's ten-vial Discovery board, an optimized local benchmark measured the previous 2D rebuild at 1,306.01 ms and the new reflow at 0.49 ms. In the live Mac UI, the helper control returned in about 306 ms in 2D and 564 ms in 3D; those UI figures include layout and SwiftUI work and are not device frame-time claims.

The Journey acceptance pass opened the map, selected Ready to blend, verified its automatic first-use mixer guide, dismissed and replayed the guide, completed the stop, followed Next to One step heavier, and paged through its density and heavier-liquid teaching. Completion remained shared with the lab and reported neutral assistance history correctly.

## Verification

- Local particle positions and inventory are preserved through helper addition and one-row/two-row reflow.
- Add, upgrade, second helper, Undo and liquid visibility pass in Classic, 2D and 3D.
- All 100 Sorting Course boards, every-fifth Discovery cadence, helper/save/Undo and completion-history checks pass.
- All 18 cross-lab/presentation concurrency cases plus density, Discovery and machine cases pass.
- Course 45's reported 3D pours and completed tall 2D vial regression continue to pass.
- Journey's 19 current stops are reachable and solvable; navigation, teaching persistence/replay, migration and reset checks pass.
- macOS Debug and signed physical-iPad Debug builds pass.
- The signed build was installed and launched on Eddie's connected iPad with existing app data preserved.
