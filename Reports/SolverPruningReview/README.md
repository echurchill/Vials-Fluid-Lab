# Review of the inherited solver pruning patch

Reviewed September 16, 2026 against Fluid Lab commit `143bc9e`. Review only: the patch has not been applied to application source. The user's supplied patch is preserved as [proposed.patch](proposed.patch).

## Applicability

`Vials/Game/VialLevelGenerator.swift`, `LevelSolver.moves(for:)`, retains the exact pruning condition targeted by the patch. `git apply --check` succeeds. This solver is reachable through the comparison screen's **Original game** menu, whose ContentView calls its generation, hint, history-recovery and minimum-move functions.

The error matters when capacities differ: a full single-color vial can still need to move so its contents join more of that color in a larger vial and free its smaller container for a different color. The current solver discards that necessary move to an empty vial.

## Reproduced using the actual Swift solver

The [reproduction](repro.swift) uses normal vials, with stacks listed bottom to top:

| Vial | Capacity | Contents |
| --- | ---: | --- |
| A | 2 | Ember, Ember |
| B | 3 | Empty |
| C | 3 | Tide, Ember, Tide |

Current source: `canSolve: false`, `minimumMoves: nil`, `hint: deadEnd`.

A temporary generator copy containing the patch's logic: `canSolve: true`, `minimumMoves: Optional(4)`, hint begins by moving two Ember units from A to B. The hint search reported a six-move route; it does not promise the minimum route. The four-move solution is A→B, C→A, C→B, C→A, producing two Tide units in A, three Ember units in B, and an empty C.

Both binaries compiled the repository's real supporting game models. Only the patched generator was copied into `/tmp/vials-prune-review`; no application source, installed app, saved progress or original Vials checkout was modified. This focused reproduction establishes the defect and correction, not a full level-generation regression result.

## Comparison-board solver

Classic, 2D Fluid and 3D Fluid presentations share `Vials/FluidLab/LabBoard.swift`, not the inherited LevelSolver. LabBoardState uses one capacity for all vials and no receive-only rules. Its homogeneous-source-to-empty pruning is valid under those assumptions: transferring the whole homogeneous stack to an identical empty vial only permutes vial contents, and its search key already treats those permutations as equivalent. Extra units of the same color elsewhere do not invalidate that symmetry. Do not transplant this patch into that solver simply because it contains a superficially similar condition.

Revisit both pruning and canonical search keys if the comparison board gains different capacities or destination-only rules; those vials would no longer all be interchangeable. Its automated trial move chooser has a similar homogeneous-to-empty exclusion and would need the same review at that point. Different rendered shapes currently do not change the logical four-unit capacities.

## Follow-up

Recommend applying the supplied fix to the bundled Original game solver, adding this false-dead-end example as a regression, and running the existing generated-level validation suite. Include duplicate colors, variable capacities, receive-only vials and helper-beaker hints. The change broadens legal search branches, so check node-limit/performance behavior as well as solvability before deployment. This review does not establish that the patch resolves every possible pruning or bounded-search issue.

The current comparison-board physics, concurrent pours and animation are unrelated to this defect.
