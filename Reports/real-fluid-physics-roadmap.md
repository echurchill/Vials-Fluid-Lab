# Real Fluid Physics Roadmap

Date: 2026-08-29

## Executive Summary

The game should not move straight from the current discrete stack model to a full real-time particle simulator for normal play. The puzzle rules depend on exact fluid units, undo, solvability, level generation, and clear player intent. A true continuous fluid simulation would make those systems harder to reason about and could introduce visual states that do not match the puzzle state.

The recommended path is staged:

1. Build a geometry-correct 2D liquid renderer that fills arbitrary beaker silhouettes by volume.
2. Add visual-only fluid dynamics: waves, meniscus, streams, splashes, bubbles, foam, viscosity, and material highlights.
3. Introduce a deterministic fluid behavior engine for puzzle interactions such as density, fire, freezing, reactions, separation, and filters.
4. Prototype true particle or grid-based physics in a sandbox mode after the visual and rule architecture are stable.

This keeps the core game relaxing, readable, and solvable while still opening a path toward richer physics-driven puzzle ideas.

## Goals

- Make every fluid visually touch the beaker walls correctly.
- Preserve fixed unit height within a specific container capacity.
- Support beakers with different heights and eventually different profiles.
- Improve pour animation so it feels continuous, intentional, and material-specific.
- Keep undo deterministic and cheap.
- Keep generated levels solvable.
- Allow future interactions without rewriting the renderer again.
- Support iPhone and iPad performance budgets.
- Avoid visual effects that obscure the puzzle state.

## Non-Goals For The First Pass

- No fully continuous SPH or FLIP simulation in production gameplay yet.
- No mixing between different fluids unless explicitly introduced as a puzzle rule.
- No stochastic gameplay outcomes.
- No hidden reactions that surprise the player after the fact.
- No reliance on frame-rate-dependent simulation state for correctness.

## Current Model

The game currently treats each beaker as a stack of discrete fluid units. This is good for:

- Solvability checks.
- Minimum-move calculation.
- Undo and restart.
- Generated levels.
- Clear win detection.
- Readability.

The visual layer, however, is beginning to behave more like material rendering than plain colored rectangles. That is also good, but it needs stricter boundaries:

- The game state should remain the source of truth.
- The visual layer should animate transitions between valid game states.
- Visual decorations should not create apparent extra fluids, missing fluids, or mixed fluids.

The recent rendering bugs around muddy color, ghost highlights, and odd masking are exactly the type of failure that happens when transient animation state and persistent stack rendering share too much responsibility.

## Recommended Architecture

### Core State

Keep core state discrete:

```swift
struct Vial {
    let capacity: Int
    var fluids: [Fluid]
}

struct Fluid {
    let colorID: FluidColorID
    let materialID: FluidMaterialID
}
```

For future interactions, extend fluids with traits rather than replacing the model:

```swift
struct FluidMaterial {
    let density: Double
    let viscosity: Double
    let opacity: Double
    let surfaceTension: Double
    let behaviorTags: Set<FluidBehaviorTag>
}
```

The key is that one "unit" still exists. The visual system can make a unit look alive, but the game knows exactly where that unit is.

### Container Geometry

Introduce a `ContainerGeometry` abstraction:

```swift
struct ContainerGeometry {
    let capacity: Int
    let outline: BeakerOutline
    let innerMask: BeakerMask
    let volumeTable: [VolumeSlice]
}
```

Responsibilities:

- Describe the drawable interior.
- Convert unit volume into vertical fill positions.
- Provide wall boundaries for clipping.
- Provide anchor points for pours.
- Support different heights and future shapes.

This is the most important foundation for "realer" liquid. If the renderer knows the shape of the container, liquid can fill the shape naturally without a full physics engine.

### Visual State

Add a visual-only layer that describes transition state:

```swift
struct PourVisualState {
    let sourceID: ContainerID
    let destinationID: ContainerID
    let fluid: Fluid
    let units: Int
    let phase: PourPhase
    let startTime: TimeInterval
    let duration: TimeInterval
}
```

The renderer can use this to draw:

- Source surface dropping.
- Destination surface rising.
- Pour stream traveling from source to destination.
- Material effects along the stream.
- Temporary ripples or splashes.

At the end of the animation, only the already-approved game state should remain.

## Milestone A: Geometry-Correct Liquid Rendering

This should come before true particles.

### Work Items

- Define a reusable beaker interior mask.
- Build a volume-to-height table for each beaker capacity and outline.
- Render each fluid layer clipped to the beaker interior.
- Ensure layers stack from the bottom of the interior, not from a guessed rectangle.
- Preserve equal unit volume inside each beaker.
- Keep beaker top lines visually dimmer than side walls, as currently preferred.
- Keep the cup derived from the bottom of the beaker geometry.

### Implementation Notes

The current beaker shape is close to a rounded-bottom test tube or beaker. For every capacity, each unit should represent the same fraction of the container's available liquid volume. On a rounded bottom, the lowest unit may occupy more vertical pixels than a middle unit if it is truly volume-correct. That can be visually surprising, so there are two options:

1. Puzzle-unit uniformity: every unit has the same vertical height, and the bottom unit is clipped by the rounded shape.
2. Physical-volume uniformity: every unit has the same area/volume, so unit heights vary in curved parts.

The tester feedback strongly favors option 1 for now. The player expects a unit to look like a unit. Use uniform puzzle units within a given beaker and rely on clipping/waves to sell the shape.

### Acceptance Criteria

- Every filled beaker looks filled to the same logical height for the same capacity.
- No fluid appears detached from side walls.
- No layer appears to sit at the wrong vertical position.
- Empty beakers show no ghost material artifacts.
- Cup, beaker bottom, and fluid bottom use the same bottom geometry.

## Milestone B: Improved Pour Animation

The current pour animation is better after switching to a moving stream tail, but there is room for a richer system.

### Desired Pour Sequence

1. Player selects source.
2. Source gently lifts or leans.
3. The source top surface tilts toward the destination.
4. A stream begins near the source lip.
5. Destination receives the stream with a splash/ripple.
6. Source fluid level lowers during the pour.
7. Destination fluid level rises during the pour.
8. Stream tapers off.
9. Both surfaces settle.
10. Final static state renders from canonical game state.

### Timing Model

Use a duration based on material and number of units:

```swift
duration = baseMaterialDuration
         + perUnitDuration * Double(units)
         + distanceDuration * normalizedDistance
```

Suggested values:

- Clear/thin fluid: 0.34 to 0.46 seconds for one unit.
- Standard fluid: 0.42 to 0.56 seconds for one unit.
- Creamy/viscous fluid: 0.58 to 0.78 seconds for one unit.
- Dense fluid: lower arc, thicker stream, slightly slower settling.
- Sparkling fluid: quicker droplets, more bubbles, lighter stream.

### Animation Phases

Use explicit phases rather than one progress value doing everything:

```swift
enum PourPhase {
    case preparing
    case streamStarting
    case transferring
    case streamEnding
    case settling
    case complete
}
```

This prevents the "empties, refills, then erases" look because source and destination masks can be coordinated by phase.

### Source Rendering During Pour

Do not mutate the visible source stack immediately unless the animation owns a matching visual replacement.

Recommended approach:

- Keep the source's pre-pour stack visible.
- Overlay an animated mask that removes the poured amount from the top over time.
- Never expose the next fluid layer through the wrong material effect.
- At completion, switch to the committed post-pour state.

### Destination Rendering During Pour

Recommended approach:

- Keep the destination's pre-pour stack visible.
- Overlay only the incoming fluid layer as it rises.
- Clip the incoming layer to the destination interior.
- At completion, switch to committed post-pour state.

### Stream Rendering

The stream should be material-specific:

- Clear: thinner stream, brighter highlight, crisp droplets.
- Standard: medium stream, soft highlight.
- Dense: lower arc, wider stream, fewer droplets.
- Creamy: slow stream, rounded front, soft edges.
- Sparkling: bubbles in stream and destination splash.

### Acceptance Criteria

- No hidden or lower fluid changes appearance during a pour.
- No temporary dark/muddy colors appear.
- No stream remains visible after completion.
- Multi-unit pours read as one continuous pour, not repeated erasing.
- Undo during or immediately after animation returns to a clean state.

## Milestone C: Visual-Only Material System

This is the safest way to get the "real fluid" feeling without making the puzzle hard to debug.

### Material Properties

Each material can define:

- Base color.
- Highlight color.
- Shadow color.
- Viscosity.
- Bubble density.
- Speckle density.
- Surface wobble.
- Pour arc height.
- Stream width.
- Settle duration.
- Glow.
- Opacity.

### Merging Same Materials

When adjacent units have the same fluid, the renderer should merge them into one visual region.

Example:

```swift
[blue, blue, blue, orange]
```

Should render as:

- One three-unit blue region with one top surface.
- One orange region with one top surface.
- No internal dividing lines within the blue region unless a subtle material texture demands it.

This improves physicality and readability.

### Texture Rules

- Texture must be clipped per merged region.
- Texture should not cross into other colors.
- Top-surface highlights should only appear on the top of each merged visible region if that region is exposed or if the design intentionally shows internal surface boundaries.
- Avoid random per-frame texture positions. Seed texture by container ID, layer index, and material ID.

### Acceptance Criteria

- Same adjacent fluids look visually continuous.
- Different fluids remain clearly separated.
- Material effects are stable when selecting/unselecting a beaker.
- Restart produces the same visual state.
- No material effect uses stale masks from a previous container.

## Milestone D: Deterministic Interaction Engine

Before real particles, build deterministic interaction rules.

### Why This Comes Before True Physics

Future puzzle elements need to be solved, tested, undone, and generated. A deterministic interaction engine can handle this. A continuous fluid simulator cannot easily promise that the same player action always produces a solvable, explainable state.

### Suggested Model

```swift
struct InteractionRule {
    let trigger: InteractionTrigger
    let condition: InteractionCondition
    let result: InteractionResult
}
```

Examples:

- When fire fluid contacts fuel fluid, convert top fuel unit to flame for three moves.
- When dense fluid is poured above light fluid, reorder the affected connected segment after settling.
- When acid contacts base, both convert to neutral fluid.

### Rule Timing

Rules should resolve at explicit times:

- Immediately after a pour.
- After a settle phase.
- At the start or end of a move.
- When a special tool is used.

Avoid rules that tick every frame.

### Solver Impact

Every interaction expands the search space. Add only one interaction family at a time and update:

- State canonicalization.
- Legal move generation.
- Win condition.
- Undo snapshot.
- Level validation.
- Difficulty scoring.
- Minimum-move solver limits.

## Milestone E: True Physics Sandbox

Only after the previous milestones are solid should we prototype real physics.

### Options

#### SpriteKit

SpriteKit can provide 2D physics bodies and particle effects. It is a good candidate for:

- Splash particles.
- Decorative droplets.
- Simple collision between visual particles and beaker masks.
- Experimental sandbox screens.

It is less ideal as the source of truth for puzzle state.

#### SwiftUI Canvas

SwiftUI Canvas is a good fit for custom 2D drawing:

- Beaker outlines.
- Clipped liquid regions.
- Procedural highlights.
- Bubbles and sparkles.
- Lightweight animation.

This is likely the best production path for the near-term app.

#### Metal Compute

Metal compute is the path for a serious fluid simulator:

- SPH particles.
- Grid-based shallow-water simulation.
- FLIP/PIC-style experiments.
- Thousands of particles with custom kernels.

This is powerful but expensive in engineering time. It should be kept behind a prototype module until proven.

#### Accelerate

Accelerate may help with:

- Numeric kernels.
- Vectorized grid updates.
- Image processing or convolution-style smoothing.
- Efficient lookup table generation.

It is not a rendering framework, but it can support CPU-side simulation experiments.

## Device Performance Budget

Target devices:

- iPhone Pro Max.
- Standard iPhone.
- iPad.
- macOS for development.

Recommended budgets:

- 60 fps during normal play.
- 30 fps acceptable only for heavy prototype sandbox modes.
- Under 4 ms per frame for fluid drawing on typical levels.
- Under 1 ms per frame for decorative particles on normal levels.
- Keep generated-level solving off the main actor.
- Avoid unbounded particle counts.
- Avoid per-frame allocation of large arrays.

### Particle Count Guidance

For production visual particles:

- 20 to 80 decorative droplets total during a pour.
- 5 to 20 splash particles at the destination.
- 0 to 12 bubbles per visible sparkling layer.
- Seeded, reusable particle pools.

For prototype true physics:

- Start with 256 particles in one beaker.
- Increase to 512.
- Increase to 1,024 only after measuring.
- Do not combine true simulation with all active beakers at once until the sandbox proves stable.

## Debugging And Tooling

Add debug overlays:

- Container interior mask.
- Fluid unit boundaries.
- Merged region boundaries.
- Pour source and destination anchors.
- Stream path.
- Current animation phase.
- Current canonical state key.
- Solver minimum move count when available.

Add deterministic visual modes:

- Disable animation.
- Disable material texture.
- Disable particles.
- Freeze animation time.
- Show raw stack indices.

These will make future visual bugs far easier to isolate.

## Test Plan

### Unit Tests

- Volume mapping for each beaker capacity.
- Legal move generation.
- Same-material merge grouping.
- Interaction rule resolution.
- Undo snapshots.
- Win detection.
- Minimum-move solver on small known levels.

### Visual Regression

- Snapshot easy, medium, hard levels across desktop and iPhone Pro Max sizes.
- Snapshot empty beakers, full beakers, cup states, selected states, and pouring states.
- Compare masks for beaker bottom and cup bottom.
- Verify top line dimming remains consistent.

### Runtime QA

- Select and unselect each beaker repeatedly.
- Restart after several moves.
- Undo after a multi-unit pour.
- Move between levels while minimum solver is still running.
- Test with Reduce Motion enabled.
- Test narrow iPhone viewport.

## Risks

### Visual State Divergence

Risk: Animation layer shows something different from the game state.

Mitigation: Static render always comes from canonical state. Animation overlays are temporary and phase-owned.

### Solver Explosion

Risk: Interactions and variable containers make level generation too slow.

Mitigation: Add rule-aware pruning, background generation, per-mode complexity budgets, and cached generated levels.

### Device Performance

Risk: Particles or Metal simulation drains battery or drops frames.

Mitigation: Keep true physics out of production gameplay until measured. Use visual-only particles first.

### Readability

Risk: Realistic rendering makes colors harder to distinguish.

Mitigation: Use stylized materials. Preserve strong silhouettes and high-contrast bands.

### Animation Bugs

Risk: Ghost highlights or stale masks return.

Mitigation: Seed textures deterministically, make masks local to a render pass, and avoid persistent highlight state inside reusable fluid views.

## Proposed Work Breakdown

### Phase 1: Rendering Stabilization

- Formalize `ContainerGeometry`.
- Refactor beaker and cup to share bottom geometry.
- Make fluid clipping use the container interior mask.
- Render merged same-material regions.
- Add deterministic material texture seeds.
- Add visual debug overlays.

### Phase 2: Pour System

- Add explicit pour phases.
- Animate source lowering and destination rising.
- Add material-specific stream timing.
- Add destination ripples and settle.
- Support Reduce Motion fallback.
- Add animation-state tests where possible.

### Phase 3: Interaction-Ready Model

- Add material traits.
- Add rule trigger points.
- Add state canonicalization for interaction outcomes.
- Add first deterministic interaction prototype, probably density.

### Phase 4: Physics Sandbox

- Create an isolated physics experiment screen or debug mode.
- Compare SpriteKit visual particles against Canvas procedural particles.
- Prototype a tiny Metal or CPU grid simulation only after profiling the simpler approach.
- Decide whether true physics should remain a toy/sandbox or graduate into production visuals.

## Recommended Next Implementation Step

The immediate next step should be Phase 1 plus the first half of Phase 2:

- Build a shared geometry/mask abstraction for beakers and cups.
- Make merged fluid regions the default.
- Replace the current one-progress pour animation with explicit phases.
- Add a debug toggle for fluid masks and layer boundaries.

That work directly addresses the current visual artifacts and creates the foundation needed for any later fluid physics.

## References

- Apple SwiftUI Canvas documentation: https://developer.apple.com/documentation/swiftui/canvas
- Apple SpriteKit physics documentation: https://developer.apple.com/documentation/spritekit/skphysicsbody
- Apple SpriteKit world documentation: https://developer.apple.com/documentation/spritekit/skphysicsworld
- Apple Metal documentation: https://developer.apple.com/documentation/metal
- Apple Accelerate documentation: https://developer.apple.com/documentation/accelerate
