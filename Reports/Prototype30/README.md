# Prototype 30 — Keystone laboratory slice

> The September 19 flattened-vial proportions below were rejected. They are superseded by the [round-vial recovery](../Prototype31/README.md). Keep the Density setup correction separate from that visual history.

September 18, 2026

## September 19 Density setup revision

The first Density setups had vertically inverted starting stacks: a heavier unit sat above a lighter one before the player touched the board. The five authored starts now obey the same heavy-to-light settlement rule as play:

| Level | Starting source vials | Target arrangement |
| --- | --- | --- |
| Heavy landing | One Light Tide; one Heavy Ruby | One two-unit target |
| Three deep | Separate Light Tide, Medium Sun, and Heavy Ruby units | One three-unit target |
| Shades of blue | Three separate Tide units, one at each density | One three-unit target |
| Twin columns | Two Heavy units together; Medium below Light in another source | Two two-unit targets |
| Against the pour | Heavy pair at A, Medium pair at B, Light pair at E | Two three-unit targets at C and D |

The introductory sources *contain* one unit but keep ordinary vial capacity and height; they are not miniature one-unit-capacity vessels. Authored hint routes were updated so early targets visibly settle when denser material is poured last, and the final level can be solved from the grouped sources in six pours. A versioned save migration replaces only old Density board checkpoints; Sorting, Mixing, and Crossover progress is retained. Automated model validation now asserts that all Density and Crossover starting vials are physically settled. Mac visual inspection confirmed the first and final Density board layouts in 3D Fluid.

## September 19 cross-lab vessel proportions

The first-level Sorting, Density, and Mixing screenshots exposed a shared-profile mistake, not a camera or vial-count effect. Vessel height had been exactly proportional to capacity: a one-unit vial was one-quarter as tall as a four-unit vial. All three presentations use that profile, so the progression was visible in Classic, 2D Fluid, and 3D Fluid. A first attempt to preserve equal unit volume by making the shorter-capacity vessels very narrow revealed a second 2D-only squeeze: the planar renderer independently forced cross-sectional area to scale with capacity. That made the one-unit vessels look like pencils.

The revised profile holds each vessel shape's screen-facing width constant across capacities. Capacities 1, 2, 3, and 4 use 85%, 90%, 95%, and 100% of the reference height; capacities 5 and 6 continue to grow taller. In 3D, smaller vessels use less front-to-back depth to retain equal physical volume per unit without sacrificing the visible width of the glass or its graduation marks. Classic and 2D use the same height and width profile, and 2D no longer applies a second capacity-based area squeeze. Apparatus badges remain horizontal. Mac visual review compared Mixing level 5's 1-, 2-, 3-, and 4-unit vials in Classic, 2D, and 3D. The geometry regression checks equal screen-facing widths for each shape over capacities 1–6. Keystone session validation covers one-unit 2D Mixing pours in levels 1 and 5; Mac Metal checks for those two 3D pours committed with 99.4% and 99.5% particle arrival before correction, respectively. A signed iPad Release build was installed and launched. Direct captures of Mixing level 5 in all three presentations confirm that the mixed-capacity vessels no longer collapse into pencil-thin silhouettes.

This implementation is the first playable slice of the four-laboratory structure proposed in [`../fluid-logic-laboratory-design.md`](../fluid-logic-laboratory-design.md) and planned in [`../keystone-lab-prototype-plan.md`](../keystone-lab-prototype-plan.md). Those documents are themselves companions to [`../3d-fluid-simulation-plan.md`](../3d-fluid-simulation-plan.md).

## Outcome

The existing Fluid Lab app now contains four independently selectable disciplines:

- **Sorting Lab** — the existing 16-level color-sorting progression, unchanged in rules and still capable of dependency-safe simultaneous pours.
- **Density Lab** — five target-matching levels in which any material can enter a non-full ordinary vial and stable gravity settlement orders heavy, medium, then light material from bottom to top.
- **Mixing Lab** — five target-matching levels using a two-input mixer. Each activation consumes one unit from each input and produces two units of the authored secondary color in a source-only output vial.
- **Crossover Lab** — five levels combining density settlement, primary-color mixing, and whole-batch density modifiers.

The lab selector, presentation selector, and pace selector are independent. Each discipline remembers its most recently visited level, while every level retains its own board, undo history, completion state, and presentation-independent logical state.

## Implemented game vocabulary

### Materials and density

Every unit now has a mutable pigment and a density of Light, Medium, or Heavy. Existing saves migrate to Medium without changing their sorting behavior. The renderers derive a shared visual material ID from both properties:

- Light uses a pastel tint.
- Medium retains the established palette.
- Heavy uses a dark tint.
- Debug/target rows also print `L`, `M`, or `H`, so density is not communicated by color alone.

Density and Crossover pours accept different materials in an ordinary destination. The canonical state settles after each committed pour, preserving the relative order of equal-density units.

### Targets

Experimental levels use outlined targets attached to actual board vials. A target specifies exact bottom-to-top pigment and density. Completing every target solves the level; harmless surplus material in other vials does not invalidate success.

### Apparatus

- A mixer has two one-unit input vials and a source-only output vial. The initial recipe set is red + yellow → orange, yellow + blue → green, and blue + red → violet. Inputs must have the same density; the result preserves it.
- A density modifier operates on an entire homogeneous batch in its chamber. It moves that batch one step lighter or heavier and refuses mixed batches or movement beyond Light/Heavy.
- Invalid setups remain recoverable because input/chamber vials can pour back out.

Apparatus activation is an undoable operation and is included in save/restore and hints.

## Level slice

Each new discipline has five levels arranged as a small teaching arc:

| Density | Mixing | Crossover |
| --- | --- | --- |
| Heavy landing | Warm blend | Equal partners |
| Three deep | Cool blend | Weighted orange |
| Shades of blue | Violet reaction | Layer cake |
| Twin columns | Color wheel | Twin products |
| Against the pour | Measured batch | Full spectrum |

Every experimental level has a validated authored route. Hints retain and advance that route from the initial state; after a deviation they fall back to the operation solver, which searches both pours and apparatus activations.

## Rendering and interaction

Classic, 2D Fluid, and 3D Fluid all render the same pigment/density variants and use the same authoritative logical state. Completion caps use the material shade in all presentations. Vial information cards remain in one row and now show current layers, density letters, target layers, rules, and apparatus ports.

Experimental pours are deliberately sequential in this prototype. Sorting keeps its existing three-or-more independent asynchronous pours. Serializing the new modes gives density settlement and apparatus input commits one deterministic order while the mechanic is being evaluated.

Apparatus transforms currently update immediately after activation rather than playing a bespoke machine animation. This is intentional prototype scope: the interaction and puzzle consequences are testable before investing in final machine art or motion.

## Validation evidence

- `Scripts/validate_keystone_labs.sh` passes all 31 catalog entries and all 15 experimental authored routes. It checks Codable round trips, material arrays, operation legality, exact target completion, and unit-ID conservation.
- `Scripts/validate_keystone_session.sh` passes every experimental level through the production session configuration. It checks initial hints, Classic pour commits, apparatus activation, solved state, complete Undo back to the initial board, deterministic experimental operation order, four-lab switching, per-lab last-level memory, and persisted metadata.
- The legacy complexity validation still solves all 16 Sorting levels and passes capacity, valve-rule, migration, and vessel-scaling checks. The two largest routes remain 51 moves for Sixfold and 44 moves for Valve Circuit.
- Clean macOS Debug and unsigned generic-iOS Debug builds succeed, including the Metal shader.

Native macOS visual inspection was unavailable at the end of this pass because the logged-in Mac session was locked. No physical iPad validation was attempted; this milestone follows the approved macOS-first strategy. Both are review tasks, not evidence gaps in the logical validations above.

## Suggested review path

1. Open **Density → Heavy landing** in Classic. Confirm dark Ember falls beneath pastel Tide and that the target card reads `H`, then `L`.
2. Open **Density → Shades of blue**. Confirm one pigment remains distinguishable as three densities by tint and letter.
3. Open **Mixing → Warm blend**. Move the two inputs into `MIX IN`, activate **Mix**, then pour the orange `MIX OUT` batch into the target.
4. Open **Mixing → Color wheel** to repeat the same machine for all three secondary colors.
5. Open **Crossover → Layer cake**. Mix orange, make it heavy, then combine it with light blue in the target.
6. Repeat representative levels in 2D Fluid and 3D Fluid, checking material tints, target readability, caps, and post-pour density settlement.
7. Deliberately make a wrong but legal experimental pour, request a hint, Undo, switch labs, and return to confirm state continuity.

## Questions this slice is meant to answer

- Are Light/Medium/Heavy readable through both tint and labels without making the palette muddy?
- Does target replication feel like a sufficiently different goal from sorting?
- Does a fixed one-unit mixer create understandable planning, or does it feel unnecessarily procedural?
- Is whole-batch density modification legible and strategically useful?
- Does Crossover create satisfying combination puzzles before more apparatus types are added?
- Which mechanics deserve richer machine presentation, and which should remain compact vial operations?
