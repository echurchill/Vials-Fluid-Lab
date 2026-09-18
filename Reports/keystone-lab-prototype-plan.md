# Keystone Lab Prototype Plan

Date: 2026-09-18
Status: Approved implementation plan; implementation has not started
Parent plan: [Vials: 3D Fluid Simulation And Gameplay Plan](./3d-fluid-simulation-plan.md)
Companion design: [Fluid Logic Laboratory: Puzzle Vocabulary And Campaign Design](./fluid-logic-laboratory-design.md)

## Purpose

Turn the three proposed keystone experiments—density, color mixing, and their crossover—into a staged implementation plan inside the existing Vials Fluid Lab app.

The app will expose four laboratories:

1. Sorting Lab: the existing sixteen sorting puzzles.
2. Density Lab: authored pattern-reproduction puzzles governed by deterministic density settlement.
3. Mixing Lab: authored color-synthesis puzzles using primary-to-secondary recipes.
4. Crossover Lab: authored puzzles combining pigment recipes and density modification.

Each laboratory shares the existing Classic, 2D Fluid, and 3D Fluid presentations. A laboratory selects rules, goals, puzzle catalog, and apparatus. A presentation selects only how the same authoritative state is displayed and animated.

This plan is an extension of the 3D fluid simulation plan, not a replacement for it. The existing separation between puzzle state, simulation, and presentation remains mandatory. The logical model decides every result; renderers animate toward that result.

## Execution Platform

Implementation and routine testing are macOS-first.

- Develop the rules, catalog, switcher, solver, persistence, Classic rendering, and most 2D/3D presentation work on macOS.
- Run automated model, solver, save, route-replay, and presentation tests on macOS.
- Use iOS Simulator for layout and lifecycle compatibility when it adds useful coverage.
- Treat physical iPad and iPhone checks as compatibility, interaction, performance, and release gates.
- Never block ordinary progress merely because an iPad or iPhone is locked, disconnected, or unavailable.
- Do not claim final iOS performance from a Mac or simulator result.

The final feature must still work on supported iOS devices. This changes the development dependency, not the shipping requirement.

## Approved Prototype Decisions

The following decisions are approved for the keystone prototypes:

1. Density Lab permits pours into any non-full ordinary vial.
2. Actual board vials are designated as targets rather than displaying a separate decorative target rack.
3. The mixer uses two fixed one-unit input ports.
4. The density modifier transforms an entire homogeneous batch in one operation.

These are prototype rules. Playtesting and solver evidence may justify revising them before a production campaign.

## Product Hierarchy

The control hierarchy is:

```text
Laboratory / ruleset
|- Sorting Lab
|- Density Lab
|- Mixing Lab
`- Crossover Lab

Presentation within every laboratory
|- Classic
|- 2D Fluid
`- 3D Fluid

Pace within every presentation
|- Relaxed
`- Quick
```

Changing presentation or pace cannot change the puzzle's logical contents, legal operations, target, Undo history, or solution.

## Laboratory Switcher

### Wide layout

Add a four-segment laboratory selector above the existing presentation controls:

```text
[ Sorting ] [ Density ] [ Mixing ] [ Crossover ]

[ Classic | 2D Fluid | 3D Fluid ]  [ Relaxed | Quick ]  [ Levels ]
```

### Compact layout

Replace the four-segment selector with a labeled menu showing the active laboratory. Do not squeeze four unreadable segments into the compact header.

### Header and metadata

The header identifies both laboratory and puzzle:

```text
VIALS / DENSITY LAB
Heavy Landing

Level 2 / 5 · 5 vials · 3 densities · Pattern target
```

The level menu lists only the active laboratory's puzzles. Completion count is also scoped to that laboratory.

### Switching behavior

When the player chooses another laboratory:

1. Checkpoint the current stable game.
2. Cancel selection, hint highlighting, and presentation-only transient state.
3. Restore the last selected level and saved game in the destination laboratory.
4. Preserve presentation and pace.
5. Rebuild the renderer from the restored authoritative state.

The selector is disabled during an active pour or machine transformation, matching the existing presentation and level controls.

## Target Presentation

Prototype targets are associated with actual vials on the board.

- A target definition refers to a board vial index and an exact bottom-to-top material sequence.
- The normal one-row vial card continues to show current contents.
- A compact target card beneath or adjacent to that vial shows the requested contents with outlined or ghost segments.
- Current contents and target contents must never use the same undifferentiated visual treatment.
- Target cards include pigment, density, and quantity in accessibility descriptions.

Example:

```text
TARGET G
top      light blue
         medium orange
bottom   heavy green
```

This design avoids a second rack of decorative vessels, keeps the goal close to its destination, and works in every presentation.

## Shared Material Rules

Color and density are independent material properties:

```text
Material portion
|- pigment
|- density
|- quantity
`- miscibility group
```

Stable unit IDs remain the basis of inventory, Undo, concurrent reservations, and render tracking. Density must not be encoded by inventing additional color integers.

Legacy sorting fluids decode as ordinary immiscible pigments with medium density.

## Keystone A: Density Lab

### Prototype rules

- Three ranks: light, medium, and heavy.
- Prototype fluids are immiscible.
- Any fluid may be poured into any non-full ordinary vial.
- After a pour, the affected vial settles deterministically by density.
- Heavy settles below medium; medium settles below light.
- Equal-density portions retain their prior relative order.
- Success requires exact matches in all designated target vials.

The unrestricted destination rule is an explicit experiment. Solver statistics and playtesting determine whether it creates useful freedom or makes puzzles trivial.

### Density levels

| ID | Working title | Primary lesson |
|---|---|---|
| D1 | Heavy Landing | Heavy fluid sinks below light fluid |
| D2 | Three Deep | Introduce all three density ranks |
| D3 | Shades of Blue | Distinguish one pigment at different densities |
| D4 | Twin Columns | Coordinate two target patterns |
| D5 | Against the Pour | Use settlement order intentionally in a capstone |

### D1: Heavy Landing

- Two pigments.
- Two density ranks.
- One target vial.
- Generous empty capacity.
- An obvious initial operation.

Goal: establish that pour order and final settled order can differ.

### D2: Three Deep

- Three pigments.
- Light, medium, and heavy material.
- One three-layer target.
- One generous storage vial.

Goal: teach the complete density order without additional constraints.

### D3: Shades of Blue

- Multiple portions share the same blue pigment but have different densities.
- Brightness, texture, motion, and density glyphs all participate in identification.
- The target requires the portions in a particular density order.

Goal: determine whether density remains readable independently of hue.

### D4: Twin Columns

- Two designated targets.
- Limited spare capacity.
- Some material could be allocated to either target.

Goal: introduce allocation and ensure density is more than a settling animation.

### D5: Against the Pour

- Two targets.
- All three densities.
- At least one operation that looks wrong under ordinary sorting intuition but settles correctly.
- More than one valid solution when practical.

Goal: test whether density creates a satisfying insight.

### Density acceptance gate

Proceed to a broader density campaign only if testers can:

- Predict post-settlement order before pouring.
- Identify density without relying exclusively on brightness.
- Explain why the target succeeded.
- Find D4 and D5 meaningfully different from ordinary sorting.

## Keystone B: Mixing Lab

### Prototype rules

- All ingredients use medium density.
- Red plus yellow produces orange.
- Yellow plus blue produces green.
- Blue plus red produces purple.
- One unit of each primary produces two units of the secondary.
- Volume is conserved.
- Undefined combinations cannot be mixed.
- Outside the mixer, fluids remain immiscible.
- Separation is not included in this prototype.

### Mixer interaction

The prototype mixer reuses the existing tap-to-pour grammar:

1. Select a source vial.
2. Tap one of two one-unit mixer inputs.
3. Fill the second input.
4. Show the recognized recipe and output preview.
5. Enable the Mix action.
6. On activation, place two output units in the output chamber.
7. Treat the output chamber as a legal source.

Invalid combinations remain recoverable in their input ports. The mixer never destroys or silently changes them.

The fixed one-unit inputs make exact dosing understandable without introducing the pipette in this prototype.

### Mixing levels

| ID | Working title | Primary lesson |
|---|---|---|
| M1 | Warm Blend | Red plus yellow makes orange |
| M2 | Cool Blend | Yellow plus blue makes green |
| M3 | Violet Reaction | Blue plus red makes purple |
| M4 | Color Wheel | Produce all three secondary pigments |
| M5 | Measured Batch | Produce multiple exact quantities from limited primaries |

### M1 through M3

Each level introduces one recipe with enough space and material to experiment safely. The recipe is displayed directly on the mixer.

### M4: Color Wheel

- Produce orange, green, and purple.
- Provide exactly enough ingredients for one batch of each.
- Provide generous storage.
- Use no density behavior.

Goal: test whether recipes form an understandable, reusable language.

### M5: Measured Batch

- Two or three target vials request different quantities.
- Primary ingredients are limited.
- Operation order and temporary storage matter.
- Targets must match exactly even if harmless excess material is permitted elsewhere.

Goal: test whether conserved volume creates planning rather than bookkeeping.

### Mixing acceptance gate

Proceed only if:

- Players understand that two input units produce two output units.
- Recipe previews remove guesswork.
- Exact quantities create planning without excessive repetition.
- The mixer feels like a new verb rather than a decorative destination vial.

## Keystone C: Crossover Lab

### Prototype rules

- Mixing requires both inputs to have the same density.
- The secondary product inherits that density.
- A density modifier changes a homogeneous batch by one rank per activation.
- The modifier processes the entire homogeneous batch in its chamber.
- Pigment does not change during density modification.
- Targets specify pigment, density, and quantity.
- Volume is conserved across every operation.

### Density modifier interaction

The modifier has:

- One input chamber.
- A clearly labeled lighter or heavier direction.
- Capacity for a homogeneous batch.
- An output preview.
- An explicit activation action.

It rejects mixed pigments, over-capacity input, material already at the requested density limit, and any state that cannot be transformed deterministically. Rejection explains the violated rule without altering contents.

### Crossover levels

| ID | Working title | Primary lesson |
|---|---|---|
| X1 | Equal Partners | Match ingredient densities before mixing |
| X2 | Weighted Orange | Mix first, then make the product heavy |
| X3 | Layer Cake | Place a manufactured pigment into a density pattern |
| X4 | Twin Products | Produce two colors with different densities |
| X5 | Full Spectrum | Multi-target crossover capstone |

### X1: Equal Partners

- Red and yellow begin at different densities.
- Modify one ingredient so the mixer accepts the pair.
- Target medium orange.

Goal: teach the equal-density mixing requirement.

### X2: Weighted Orange

- The starting ingredients already match.
- Mix orange first.
- Move the complete output batch through the heavy modifier.
- Target heavy orange.

Goal: teach operation order with minimal routing complexity.

### X3: Layer Cake

- Manufacture heavy orange.
- Combine it with existing medium and light material.
- Reproduce one layered target.

Goal: connect transformation to automatic settlement.

### X4: Twin Products

- Produce two secondary pigments.
- One target product must be light and the other heavy.
- Temporary storage is constrained.

Goal: coordinate mixer and modifier operations.

### X5: Full Spectrum

- Two target vials.
- Primary and secondary pigments.
- All three densities.
- Limited ingredients.
- At least two valid solutions when practical.
- No separator, property filters, or limited machine charges.

Goal: determine whether the combined system produces synthesis rather than busywork.

### Crossover acceptance gate

Proceed only if:

- Players treat pigment and density as separate properties.
- Mixer output can be predicted before activation.
- Required operation order is discoverable from the board.
- The capstone feels clever rather than laborious.

## Step-By-Step Implementation

### Step 1: Freeze the sorting baseline

- Record all sixteen current starting states and proven routes.
- Preserve current save-decoding fixtures.
- Retain presentation parity, concurrent-pour, hint, and performance checks.
- Record a representative macOS visual and timing baseline.

Gate: subsequent model migrations leave every Sorting Lab level unchanged.

### Step 2: Introduce a laboratory catalog

Add a ruleset identity separate from presentation, tentatively:

```swift
enum LabDiscipline {
    case sorting
    case density
    case mixing
    case crossover
}
```

Move puzzle metadata toward definitions rather than extending one monolithic enum:

```swift
struct LabPuzzleDefinition {
    let id: LabPuzzleID
    let discipline: LabDiscipline
    let title: String
    let initialState: LabBoardState
    let goal: LabGoal
    let rules: LabRuleSet
    let apparatus: [LabApparatus]
}
```

Keep the current sixteen puzzles as the Sorting Lab catalog.

Gate: existing puzzles load through the new catalog with no behavior change.

### Step 3: Add the laboratory switcher

- Add the wide four-segment control.
- Add the compact menu fallback.
- Filter levels by discipline.
- Scope completion counts to the selected laboratory.
- Preserve presentation and pace across laboratory changes.
- Add appropriate keyboard and VoiceOver labels on macOS.

Gate: all four laboratories can be selected as placeholders without affecting Sorting Lab progress.

### Step 4: Namespace persistence

Persist:

- Selected laboratory.
- Last selected puzzle per laboratory.
- Saved game per laboratory and puzzle ID.
- Completion status per laboratory and puzzle ID.
- A schema version.

Migrate legacy saves into Sorting Lab without losing completion state.

Gate: repeated laboratory switches and macOS app relaunches restore all four laboratories independently.

### Step 5: Expand material identity

Introduce independent pigment, density, and miscibility metadata while retaining stable unit IDs. Provide compatibility accessors as needed during migration, but do not encode density into pigment IDs.

Gate: all Sorting Lab keys, moves, solutions, Undo histories, and render colors remain correct.

### Step 6: Implement target goals

Add an exact-target goal alongside monochrome sorting:

```swift
enum LabGoal {
    case monochromeSort
    case exactTargets([LabVialTarget])
}
```

Implement exact bottom-to-top matching, target cards, completion text, accessibility descriptions, and solver goal checks. Validate first with a hidden development puzzle using existing materials.

Gate: the same target completes in Classic, 2D Fluid, and 3D Fluid.

### Step 7: Implement Density Lab in the model

- Add density-aware legal pours.
- Normalize a destination after every pour.
- Define stable equal-density ordering.
- Include material properties in canonical solver keys.
- Extend Undo and hints.
- Author and solve D1 through D5.

Develop and tune the first playable version in Classic on macOS.

Gate: all density levels have solver routes, Undo fidelity, deterministic replay, and stable persistence.

### Step 8: Add density presentation

Implement in this order:

1. Classic brightness, texture, glyph, and settlement animation.
2. 2D guided particle settlement.
3. 3D material treatment and guided settlement.

The 3D renderer animates toward the model result. It does not independently determine which fluid sinks.

Gate: the same route produces the same exact final state in all presentations without a late visual snap or unexplained material appearance.

### Step 9: Implement the mixer model

Generalize history and hints from pours to operations:

```swift
enum LabOperation {
    case pour(LabBoardMove)
    case activateApparatus(LabApparatusID)
}
```

Add mixer ports, recipe validation, conserved output, invalid-input recovery, operation history, solver transitions, and M1 through M5.

Gate: a unit ledger accounts for every input and output across every recipe.

### Step 10: Add mixer presentation

Build an abstract but polished Classic apparatus first, followed by 2D and 3D. All presentations share these logical milestones:

1. Inputs arrive.
2. The recipe is recognized.
3. The transformation animates.
4. Output becomes available.
5. Display and model agree before further interaction.

Gate: idle apparatus contents survive presentation changes and save restoration exactly.

### Step 11: Implement the density modifier

Add one-rank, full-homogeneous-batch transformations, preview, validation, history, solver support, and rejection messaging. Author X1 through X5 only after the density and mixing acceptance gates pass.

Gate: every crossover transformation is deterministic and reversible through Undo.

### Step 12: Extend hints and authored validation

For every experimental level:

- Store an authored intended route.
- Independently verify solvability.
- Replay the complete route through the logical model.
- Replay presentation milestones on macOS.
- Reject immediate inverse hint loops.
- Verify exact target completion.

Gate: hints never recommend an invalid machine operation or cycle between equivalent states.

### Step 13: Accessibility and readability

Verify on macOS first:

- Density does not depend on lightness alone.
- Target sequences have complete accessibility descriptions.
- Mixer recipes and output quantities are announced.
- Inputs, outputs, and activation actions have distinct names.
- Keyboard focus follows a useful order.
- Reduce Motion produces concise transformations without losing state changes.

Then repeat platform-specific checks with VoiceOver and touch on iOS when devices are available.

### Step 14: macOS integration and performance pass

Exercise all fifteen prototype levels across three presentations and two paces. Automate logical route replay for the complete matrix; use selected representative levels for detailed visual and performance inspection.

Check:

- No logical divergence by presentation or frame rate.
- No fluid level snap, duplication, disappearance, or late correction.
- Stable operation through pause, backgrounding where applicable, Undo, reset, laboratory switch, level switch, and presentation switch.
- No significant regression from the current macOS sorting baseline.

Gate: the prototypes are fully usable and routinely testable without physical iOS hardware.

### Step 15: iOS compatibility and physical-device validation

When an iPad or iPhone is available, validate rather than begin the investigation there:

- Touch target size and switcher layout.
- Compact and regular size classes.
- Density identification at normal viewing distance.
- Apparatus input selection.
- Target/current-state distinction.
- 3D settlement and transformation continuity.
- Lifecycle, memory, thermal behavior, and GPU performance.

Any iOS-only defect is fixed and regression-tested where practical on macOS or simulator. Physical-device access should be required only to confirm device-specific behavior and final performance.

Gate: supported iOS devices preserve rules and readability, and the chosen minimum physical device meets the final performance standard.

## Build Order

```text
Laboratory catalog and switcher
        |
Target goals
        |
Density model and Classic presentation
        |
Five Density Lab levels
        |
Density 2D and 3D presentations
        |
Mixer model and Classic presentation
        |
Five Mixing Lab levels
        |
Mixer 2D and 3D presentations
        |
Density modifier
        |
Five Crossover Lab levels
        |
macOS integration and performance gate
        |
iOS compatibility and physical-device gate
```

Puzzle quality is proven before investing in elaborate 3D apparatus, while all four laboratories ultimately support all three presentations.

## Automated Validation Matrix

### Model and solver

- All existing Sorting Lab solutions remain valid.
- All fifteen prototype levels have at least one valid route.
- Every authored route reaches its exact target.
- Replaying a route twice yields identical normalized states.
- Every operation conserves volume unless an explicit future rule says otherwise.
- Undo restores the complete prior state, including apparatus.
- Canonical keys distinguish materially different density, recipe, vessel, and apparatus states.

### Save migration

- Current saves decode into Sorting Lab.
- Each laboratory restores its own most recent puzzle.
- Presentation and pace remain shared preferences.
- Unknown future material or apparatus versions fail safely rather than corrupting inventory.

### Presentation parity

- Scripted operations commit the same model state in Classic, 2D, and 3D.
- Animation timing cannot change the solution.
- Presentation changes while idle preserve exact contents.
- Quick and Relaxed use different pacing but identical transitions.

### macOS interaction

- Mouse, trackpad, and keyboard can operate every required action.
- Wide and compact windows choose the appropriate laboratory control.
- Machine ports and target cards remain legible at supported window sizes.
- No active operation can be interrupted into an invalid state through a disabled control.

### iOS compatibility

- Touch targets meet platform expectations.
- The compact laboratory menu is readable and reachable.
- Device rotation and lifecycle transitions preserve authoritative state.
- Physical-device performance is measured before release claims.

## Prototype Success Decision

After all three keystones are playable, review them independently:

### Density succeeds if

- Settlement is predictable.
- Visual density language is readable.
- Later levels create decisions unavailable in ordinary sorting.

### Mixing succeeds if

- Recipes are understood without memorization.
- Conserved output quantities feel natural.
- Machine use creates planning rather than ceremony.

### Crossover succeeds if

- Pigment and density remain mentally separable.
- Combining the systems creates insight rather than repetitive processing.
- X5 supports multiple understandable solution routes.

Only successful keystones advance into campaign production. A failed crossover does not invalidate density or mixing as independent modes.

## Explicit Non-Goals

The keystone prototypes do not include:

- An unmixer or separator.
- Pipettes or free-form fractional doses.
- Property filters or fractionating columns.
- Limited machine charges.
- Viscosity, temperature, phase change, catalysts, or reactions.
- Generated density or chemistry levels.
- Continuous analog pouring.
- Timing-based puzzles.
- A free-form chemistry sandbox.

Those ideas remain candidates in the companion laboratory design document. The keystones exist to answer whether target patterns, density, mixing, and their first combination are worth expanding.

