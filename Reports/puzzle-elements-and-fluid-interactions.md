# Puzzle Elements And Fluid Interactions

Date: 2026-08-29

## Executive Summary

Fluid interactions can make the game much richer, but they need to stay readable, deterministic, and solvable. The best first additions are rules that feel physical but remain easy to explain in one glance:

- Density: heavy fluids sink and light fluids rise.
- Viscosity: thick fluids pour slowly or only one unit at a time.
- Fire: reactive fluids ignite or transform when touched by specific fuels.
- Fizz/foam: reactive fluids expand temporarily and create capacity pressure.
- Filters: special containers or tools transform one fluid into another.

The important design rule is that each mechanic should create new puzzle structure without making the player feel tricked. Interactions should be visible, previewable, undoable, and introduced one at a time.

## Design Principles

### Readability First

The player should know what happened and why. If a fluid catches fire, sinks, freezes, or separates, the visual language should be obvious.

### Deterministic Outcomes

The same move must always produce the same result. This keeps undo, level generation, and minimum-move logic sane.

### No Hidden Chemistry

Surprise is fun once. Confusion is not. The first level that introduces an interaction should make the rule feel inevitable.

### Small Rule Sets Per Level

Most levels should use zero or one special rule. Harder levels can combine two. More than two interaction families in one level will likely feel chaotic unless the level is intentionally experimental.

### Preserve Relaxing Play

Even with harder puzzle rules, the tone should stay cozy and playful. Avoid harsh fail states unless they are optional challenge content.

## Interaction Ideas

## 1. Density Layers

### Rule

Each fluid has a density. After a pour, connected fluids in a beaker settle by density if the rule is active for that level.

Example:

- Oil floats above water.
- Heavy syrup sinks below water.
- Mercury-like fantasy fluid sinks below almost everything.

### Visual Treatment

- Heavy fluids have a lower, thicker pour arc.
- Light fluids have softer highlights and a slightly buoyant settle.
- A short vertical shimmer indicates settling.

### Puzzle Value

Density can reverse the usual stack logic. A player may pour a heavy fluid on top, expecting it to stay there, but it falls through compatible fluids and lands lower.

### Solver Impact

Moderate. The solver needs to normalize affected beakers after each move.

### Prototype Priority

High. This is one of the best mechanics because it is intuitive and directly supports future fluid physics.

## 2. Viscous Fluids

### Rule

Thick fluids pour differently:

- Only one unit pours at a time.
- Or thick fluids require an empty destination.
- Or thick fluids cannot pour through narrow-neck containers.

### Visual Treatment

- Slower stream.
- Wider stream.
- Rounded stream front.
- Longer settling wobble.

### Puzzle Value

Viscous fluids create move-order constraints without adding destructive behavior.

### Solver Impact

Low to moderate. Legal move generation changes, but state shape remains simple.

### Prototype Priority

High.

## 3. Fire And Ignition

### Rule

One fluid ignites when poured onto or under a compatible trigger.

Possible variants:

- Spark fluid poured onto fuel becomes flame.
- Flame touching water becomes steam.
- Flame touching ice melts it.
- Flame burns away a fuel unit after a fixed number of moves.

### Visual Treatment

- Warm glow.
- Small flame flicker inside the affected unit.
- Smoke puff on extinguish.
- Top surface becomes animated but still bounded by the unit.

### Puzzle Value

Fire can transform blockers, consume excess units, or require the player to extinguish a reaction before sorting.

### Solver Impact

High if timed. Moderate if reaction resolves immediately.

### Prototype Priority

Medium. Very promising, but should come after deterministic interaction plumbing.

## 4. Freezing And Melting

### Rule

Cold fluid freezes adjacent water-like fluid into ice. Frozen units cannot pour until melted.

Possible variants:

- Ice blocks fluid below it.
- Warm fluid melts ice.
- Frozen fluid can be moved only if it is the top unit.

### Visual Treatment

- Frosted surface.
- Pale rim.
- Reduced fluid motion.
- Crack animation when melted.

### Puzzle Value

Freezing creates temporary locks without needing UI locks or keys.

### Solver Impact

Moderate to high.

### Prototype Priority

Medium.

## 5. Acid And Base Neutralization

### Rule

Acid and base transform into a neutral fluid when they touch.

Possible variants:

- Acid + base -> water.
- Acid + metal -> gas.
- Base + oil -> soap.

### Visual Treatment

- Brief fizz.
- Color flash.
- Bubbles that clear quickly.

### Puzzle Value

This lets levels include controlled transformation. It can remove blockers or create required colors.

### Solver Impact

High because the inventory of colors changes.

### Prototype Priority

Medium.

## 6. Foam And Expansion

### Rule

Some reactions create foam that temporarily occupies extra capacity.

Examples:

- Sparkling fluid expands when shaken or poured.
- Acid + base creates foam for one move.
- Foam collapses after a settle phase.

### Visual Treatment

- Bubbles at the top of the affected beaker.
- A foamy cap that visibly occupies capacity.
- Gentle popping animation.

### Puzzle Value

Foam can make capacity management interesting. A beaker that appears to have room might temporarily reject a pour.

### Solver Impact

Moderate if foam duration is deterministic.

### Prototype Priority

High for visual delight, medium for gameplay.

## 7. Oil And Water Separation

### Rule

Certain fluids do not mix and always separate after a pour.

This is related to density but has a more specific meaning:

- Oil can be poured on water.
- Water poured on oil falls below it.
- Oil layers merge with oil above compatible layers.

### Visual Treatment

- Oil has glossy, smooth highlights.
- Water remains brighter and clearer.
- Settling animation is gentle and obvious.

### Puzzle Value

This is a more approachable first version of density because most players already understand oil and water.

### Solver Impact

Moderate.

### Prototype Priority

High.

## 8. Evaporation

### Rule

Volatile fluid disappears after exposure.

Possible variants:

- If volatile fluid is the top unit for three moves, it evaporates.
- Heat makes volatile fluid evaporate immediately.
- A capped beaker prevents evaporation.

### Visual Treatment

- Vapor wisps.
- Unit becomes more transparent before disappearing.

### Puzzle Value

Evaporation can remove excess units, which supports asymmetric color counts and challenge levels.

### Solver Impact

High if move timers are involved.

### Prototype Priority

Low to medium. Useful, but less relaxing if it feels like pressure.

## 9. Catalysts

### Rule

A catalyst changes another fluid without being consumed.

Examples:

- Enzyme fluid converts milk-like fluid to gel.
- Spark fluid ignites fuel but remains spark.
- Seed crystal turns adjacent liquid into crystal.

### Visual Treatment

- Pulse from catalyst unit to target unit.
- Small shimmer line at contact boundary.

### Puzzle Value

Catalysts allow transformation puzzles without reducing inventory.

### Solver Impact

High, but manageable if immediate.

### Prototype Priority

Medium.

## 10. Filters

### Rule

A special beaker or tool filters fluid as it enters or exits.

Examples:

- Dirty fluid becomes clean.
- Sparkling fluid loses bubbles.
- Mixed fluid separates into its original components.

### Visual Treatment

- Beaker has a small filter mark or grate.
- Fluid changes color as it passes through the lip.
- Short sparkle or sediment effect.

### Puzzle Value

Filters create spatial goals. The player must route fluids through the right container.

### Solver Impact

Moderate.

### Prototype Priority

High for future levels because it creates variety without making every fluid special.

## 11. Locked Or Capped Beakers

### Rule

Some beakers cannot receive or pour until a condition is met.

Examples:

- Cap opens after a matching color touches it.
- Beaker unlocks after another beaker is solved.
- Beaker opens only when empty.

### Visual Treatment

- Subtle cap, clamp, or lock ring.
- Clear unlocked animation.

### Puzzle Value

Locks create ordering puzzles.

### Solver Impact

Moderate.

### Prototype Priority

Medium.

## 12. One-Way Beakers

### Rule

Some containers can receive fluid but cannot pour out, or can pour out only through a specific side.

### Visual Treatment

- Arrow etched on the glass.
- Different rim shape or spout marking.

### Puzzle Value

One-way rules create commitment without needing penalties.

### Solver Impact

Moderate.

### Prototype Priority

Low to medium. Interesting, but may feel less relaxing.

## 13. Splitters And Funnels

### Rule

A tool splits a multi-unit pour across two destinations or redirects a pour.

### Visual Treatment

- Temporary funnel overlay.
- Stream divides into two smaller streams.

### Puzzle Value

This creates advanced routing puzzles and supports uneven color counts.

### Solver Impact

High.

### Prototype Priority

Low until core pouring is extremely stable.

## 14. Absorbing Sponge Fluid

### Rule

A sponge-like fluid absorbs a compatible fluid and grows, then releases it when squeezed by another condition.

### Visual Treatment

- Soft porous texture.
- Unit swells slightly.
- Drops release on transformation.

### Puzzle Value

This creates storage and delayed-release mechanics.

### Solver Impact

High.

### Prototype Priority

Low.

## 15. Color-Changing Light Fluid

### Rule

Photoreactive fluid changes color when moved into a lit beaker or exposed to a lamp tool.

### Visual Treatment

- Lit beaker has a soft top glow.
- Fluid hue shifts over a short animation.

### Puzzle Value

This gives transformation without chemistry and can feel magical rather than dangerous.

### Solver Impact

Moderate.

### Prototype Priority

Medium.

## 16. Crystallization

### Rule

Certain fluids turn solid when stacked with a trigger. Solid units block movement until dissolved.

### Visual Treatment

- Faceted highlight.
- Rigid surface.
- Dissolve animation when compatible fluid touches it.

### Puzzle Value

Crystals create blockers and keys.

### Solver Impact

High.

### Prototype Priority

Medium to low.

## 17. Magnetic Or Metallic Fluid

### Rule

Metallic fluid is attracted to special magnetic beakers or tools.

Possible variants:

- Metallic fluid must end in a magnetic beaker.
- Magnet tool pulls the top metallic unit into the helper cup.
- Magnetic beaker can receive metal even when normal rules would reject it.

### Visual Treatment

- Tiny metallic sparkles.
- Subtle pull arc.
- Magnet icon on beaker.

### Puzzle Value

This adds tool-based manipulation without changing all pouring rules.

### Solver Impact

Moderate to high depending on tool use.

### Prototype Priority

Low to medium.

## 18. Heavy Sediment

### Rule

Sediment-bearing fluids leave a residue at the bottom of a beaker.

Examples:

- Dirty fluid leaves sediment after pouring out.
- Cleaner fluid removes sediment.
- Sediment occupies one unit of capacity until cleaned.

### Visual Treatment

- Thin dark layer at bottom.
- Dusty particles settle downward.

### Puzzle Value

Sediment creates memory in containers. This is powerful but potentially frustrating.

### Solver Impact

High.

### Prototype Priority

Low.

## Best First Interaction Set

For the first interaction-focused build, choose this set:

1. Density or oil/water separation.
2. Viscous fluids.
3. Foam expansion as a visual-first mechanic.
4. Filters as a container-based mechanic.
5. Fire as a later showcase after rule plumbing is stable.

This combination gives a lot of variety while staying understandable.

## Level Progression Model

### Stage 1: Pure Sorting

- Normal colors.
- Equal-height beakers.
- No interactions.
- Player learns the base rules.

### Stage 2: Capacity Variation

- Different beaker heights.
- More colors.
- Multiple vials of the same color.
- No special reactions yet.

### Stage 3: Material Personality

- Same puzzle rules, richer materials.
- Clear, dense, sparkling, creamy visuals.
- Pour timing and visual texture reinforce material identity.

### Stage 4: First Rule Interaction

- Introduce one interaction family.
- Use low vial counts.
- Include obvious examples.

### Stage 5: Combined Rules

- Combine two mechanics.
- Example: dense fluid plus filter beaker.
- Example: viscous fluid plus variable capacity.

### Stage 6: Advanced Generated Levels

- Rule-aware generation.
- Difficulty scoring accounts for transformations.
- Optional challenge labels.

## Solver And Generator Requirements

Every interaction needs the following support:

- Legal move generator update.
- State transition update.
- Canonical state key update.
- Undo snapshot update.
- Restart snapshot update.
- Solvability validator update.
- Difficulty scoring update.
- Minimum-move handling or explicit opt-out.

For generated levels, the safest approach remains reverse generation:

1. Start from a solved state.
2. Apply legal reverse moves.
3. Reject states that are visually too solved.
4. Reject states with too many bottom matches.
5. Reject states with ambiguous or unreadable special rules.
6. Validate solvability with the rule-aware solver.

## UI Communication

Special fluids need clear teaching without long text.

Recommended tools:

- Small material icons in the mode or level intro.
- Short one-line rule prompt only on first introduction.
- Visual affordances on affected fluids.
- Optional info button later, not required for prototype.
- Distinct material textures that do not depend only on color.

## Interaction Complexity Ranking

Lowest implementation complexity:

- Viscous pour timing.
- Locked/capped beakers.
- One-way beakers.

Medium complexity:

- Density/oil-water separation.
- Filters.
- Foam expansion.
- Photoreactive color change.

Highest complexity:

- Fire with timers.
- Evaporation.
- Catalysts.
- Sediment.
- Splitters/funnels.
- Sponge absorption.

## Recommended Near-Term Plan

### Next Prototype

- Improve material rendering and merged same-fluid regions.
- Make pour timing material-aware.
- Add debug visualization for unit boundaries and fluid regions.
- Add no-gameplay foam, bubbles, and density-looking settle as polish only.

### First Real Mechanic Prototype

Add density separation in a small optional test mode:

- Two or three fluid densities.
- Immediate settle after each pour.
- No reactions yet.
- Validate the solver before exposing it broadly.

### Second Mechanic Prototype

Add filters:

- One special beaker.
- One transformation rule.
- No timing.
- Clear visual conversion at the rim.

### Showcase Mechanic

Add fire:

- Immediate trigger first.
- No timers at first.
- Flame + water -> steam/clear.
- Flame + fuel -> flame.

This order builds from stable and intuitive mechanics toward more dramatic ones.

## Open Design Questions

- Should interactions live in standard levels, special mode levels, or both?
- Should the helper cup participate in interactions?
- Should transformed fluids count as new target colors or temporary states?
- Should some interactions be optional shortcuts rather than required solutions?
- Should hard levels ever contain destructive reactions?
- Should Zen mode allow wild interaction combinations once it returns?

## Recommendation

Start with physics-feeling visuals and deterministic density. That gives the biggest return for the least risk. Fire, catalysts, and deeper chemistry can become fantastic puzzle ideas, but they should wait until the interaction engine, solver, and visual debugging tools are ready.
