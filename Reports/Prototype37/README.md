# Machine guidance, Recovery and Discovery

September 20, 2026. Eddie authorized this sequence after reviewing the learning-tree picture, with an explicit requirement to preserve the accepted vial visuals. Baseline: pushed commit 59f44e9. This implementation is local and has not been pushed.

## Player-facing changes

Machine controls have an info button with a current result preview and requirements. A ready machine still activates in one tap; tapping an unavailable machine explains the blocker instead of silently doing nothing. Mixers explain input amounts, recipe compatibility, density matching and output space. Modifiers explain empty/mixed chambers and density limits. Guidance appears in a popover anchored to the machine controls, so opening it does not resize the board. Repeated separators include their input letter in the control label.

Recovery has four authored levels: **Split purple**, **Room for both**, **Second chance**, and **Keep every drop**. A separator accepts exactly two units of one secondary pigment at one density. Both outputs must be empty; each receives one primary-color unit at the original density. Purple becomes blue/red, orange red/yellow, and green yellow/blue. Parcel IDs and total volume are conserved. Later puzzles reuse the existing mixer and require keeping the remaining ingredient for another target. The transfer has a separate two-output animation path in Classic, 2D and 3D and commits once at completion.

Discovery has four authored levels: **First reveal**, **Peek ahead**, **Buried clue**, and **Hidden garden**. Only each starting top unit is identified. Gray liquid and question marks in the contents strip mark unknown portions; occupied volume and free space stay visible. Underlying identities are fixed. Grouped pours stop at the known-batch boundary, including when the unknown unit happens to be the same color. The newly exposed top unit fades into its pigment when the pour commits, using a half-second shared transition scaled by the existing pace. Reveals change color only; they do not move particles or change fill levels. They respect pause/suspension. Known identities persist through Undo, level Reset and save/relaunch; Reset all progress starts fresh.

While unknowns remain, Hint chooses using known colors, exposed layer boundaries and available space. It does not run the full-information solution search. Once all portions are known, ordinary solution hints resume. Unseen contents are also masked in accessibility descriptions; the disposable pour-comparison feature is unavailable in Discovery. Discovery is sequential for deterministic reveals; existing Sorting concurrency is unchanged.

There are now 39 levels across six labs: Sorting 16, Discovery 4, Density 5, Mixing 5, Recovery 4 and Crossover 5. The learning-tree picture remains a proposed campaign structure, not an implemented unlock system. Discovery is Sorting-only in this prototype; hidden ingredients in mixers or density-changing vessels need additional design before combining them.

## Preserving the visuals

No vessel profiles, radii, heights, capacity scaling, depth, camera/orbit defaults or glass mesh/style parameters were changed. The existing layout/profile section of LabBoardGeometry, the full LabGeometry source, and LabClassicLayout compare byte-for-byte with 59f44e9; see geometry-preservation.txt. Changes in LabBoardGeometry are confined to the shared transformation value type. The Metal shader only adds the neutral unknown-dye case; all existing encoded pigments retain their original rendering path. The 2D unknown material has no pigment-specific bubbles/glow/ribbons, and unexposed gray regions remain opaque during another portion's reveal.

The existing vessel presentation gate passes, including full small-capacity Mixing/Density routes and renders in all three presentations. New-lab offscreen captures were inspected for roundness, readable fill and neutral hidden regions. Actual Mac UI inspection verified anchored machine guidance, 3D separation/completion/caps/Next placement, a Discovery pour/reveal, and retained knowledge after Undo. Final UI checks are recorded in the follow-up below. No claim of new physical-iPad visual acceptance or performance measurement is made: Eddie explicitly said the iPad is unavailable overnight. Mac automation used caffeinate -di.

## Validation

- All 39 model fixtures round-trip through Codable and validate; experimental routes solve. All three separation recipes preserve IDs, quantity and density at each of the three density ranks. Invalid separator batch size and mismatched densities are rejected.
- The 19 Density/Mixing/Recovery/Crossover session routes and existing persistence checks pass.
- 69 animated machine cases pass in Classic/2D/3D: single commit, inventory, pause/suspension, checkpoint, double activation, final continuity, Undo and Reset. This includes the new separator and existing mixers.
- All four Discovery levels pass complete routes in all three presentations (12 cases), plus stationary reveal, pause, save, knowledge retention, reset cancellation and explicit fresh reset. Altering hidden pigments does not change the initial legal moves or exploratory hint. A same-color hidden portion cannot be silently grouped into a pour. Each authored level's visible-hint exploration reaches full knowledge with a solvable board.
- The pre-existing vessel presentation/small-capacity route suite passes. Mac and signed iOS Release builds pass. Device installation and iPad portrait/landscape acceptance are deferred.

Logs here omit unrelated SDK warnings; full transient build logs are in /tmp and generated diagnostic frame sequences remain under ignored build/recovery/validation, build/discovery/validation and build/overnight-vials/presentation. Included PNGs are selected rendered checkpoints, not photographs of the iPad.

## Morning review

Start with Recovery → Split purple, then Room for both to inspect a blocked machine. Continue through Second chance and Keep every drop. For Discovery, use First reveal: pour A into an empty vial, watch the gray portion reveal, then Undo or Reset and confirm it stays known. Compare the three presentation modes. The new labs remain small prototypes; puzzle difficulty, reveal timing and the look of the separator streams would benefit from Eddie's feedback before expansion.

Sound improvements, the broader campaign/unlock tree, further crossover mechanics and automated background performance monitoring remain deferred. The previously paused performance automation was not resumed.

## Final Mac UI follow-up

The final Release app was relaunched normally, without --lab-trial, so subsequent play saves progress. The actual Classic Room for both screen correctly explains the occupied separator output in an anchored popover. Final Classic and 2D First reveal screens show matching gray regions and question-marked strips; the corrected 2D gray material has no decorative ribbons. The app is left at **Recovery → Split purple → 3D Fluid**, unstarted, for the morning review. No iPad interaction occurred. These observations supplement the recorded 3D activation/completion/Next and Discovery pour/Undo checks.

## September 21: shared machine roles

Eddie's Recovery level 3 screenshot exposed a label omission: D is both a separator output and mixer input, but the session returned only the first apparatus associated with a vial. It now returns all associated apparatus, and the shared board overlay stacks their badges upward above the same rim anchor. Existing single-role labels retain their placement; vessel geometry/framing is unchanged. Accessibility also names each role, and ready-mixer guidance now identifies the ingredient vials by letter. Actual Mac screenshots of Second chance pass in Classic, 2D and 3D; D visibly shows SEP OUT and MIX IN. Both Release builds pass. The Mac is left on Recovery → Second chance → 3D Fluid. No iPad install or push was performed.
