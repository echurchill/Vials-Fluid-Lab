# Final-level completion control

September 19, 2026. The final level of every laboratory now shows “Final level complete. Choose a level, or play again.” and a prominent “Choose level” menu in the reserved bottom-toolbar slot between Hint and Pause. The menu shares its level list and completion marks with the existing top-right chooser. Earlier levels retain Next.

The wording deliberately does not claim the whole lab is complete: players may jump directly to the final level. The final-level action reserves its space while playing but stays hidden from sight, interaction and accessibility until solved. No new row is inserted on completion.

Validation: Release Mac and signed generic-iOS builds pass. With caffeinate running, the actual Mac UI completed Full spectrum, verified unchanged vial/card/info/toolbar vertical positions before and after solving, and exercised the final menu in Classic, 2D Fluid and 3D Fluid. Each mode showed the completion message and five menu entries; selecting Equal partners navigated correctly, and returning to Full spectrum restored its completed presentation. The chooser was absent from accessibility before completion and on the earlier level. The final screenshot was visually inspected: [completed toolbar](final-level-complete.png).

This changes the shared view for Sorting, Density, Mixing and Crossover. Physical iPad verification remains pending. Changes are local and uncommitted.
