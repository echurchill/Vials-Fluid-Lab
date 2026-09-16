# Unequal-capacity solver pruning correction

The bundled Original game's solver no longer assumes every full homogeneous vial is permanently finished. Before pruning a move from such a vial into an empty container, it now counts the board's fluid inventory. The move is pruned only when that source already holds every unit of its color.

This distinction matters when capacities differ. A full two-unit vial can need to move into an empty three-unit vial so another unit of the same color can join it, freeing the smaller vial for a different color. Equal-capacity generated boards retain the old symmetry pruning whenever the completed source owns the full color inventory.

The shared Fluid Lab board solver was intentionally not changed. Its logical capacities remain uniform, and its canonical state key treats vial permutations as equivalent; under those current rules, moving a homogeneous stack to an identical empty vial is still redundant.

## Permanent regression

The generated-level validation now includes the reviewed counterexample, with stacks listed bottom to top:

| Vial | Capacity | Contents |
| --- | ---: | --- |
| A | 2 | Ember, Ember |
| B | 3 | Empty |
| C | 3 | Tide, Ember, Tide |

The corrected solver proves it solvable, finds the four-move optimum, and starts its hint by moving both Ember units from A to B. The route is A→B, C→A, C→B, C→A.

The full optimized validation passes after the change. It covers generated Easy/Medium/Hard/Zen levels, duplicate-color and variable-capacity catalogs, all 15 receive-only experiment anchors, exact minima where required, helper-beaker hints, history recovery, tuned generation and mastery/flow checks. [Output](validation.log).

One local optimized run of the existing suite took 1.91 seconds before the patch. The patched suite, including the three new counterexample checks, took 2.25 seconds. This single end-to-end comparison includes the added regression work and is not a stable node-count benchmark, but it did not expose a practical search-limit regression in the covered catalog.

macOS Release and signed iOS Release builds pass. The signed HEAD build was installed on the connected M4 iPad Pro and relaunched normally in landscape-left. No saved player progress was required for the solver validation; the counterexample is exercised directly against the production solver implementation.

Measured 3D frame pacing remains the next open engineering item. The solver's bounded searches can still return a search-limit result for unusually expensive future boards; this correction addresses the demonstrated false pruning rather than removing those intentional limits.
