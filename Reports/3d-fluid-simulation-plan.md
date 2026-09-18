# Vials: 3D fluid simulation and gameplay plan

September 7, 2026. Planning only; no game implementation or benchmark was performed.

> **Prototype execution clarification — September 18, 2026:** The density, mixing,
> and crossover keystones associated with this plan are specified in
> [Keystone Lab Prototype Plan](./keystone-lab-prototype-plan.md). Those prototypes
> are implemented and tested macOS-first so development is not blocked by limited
> iPad or iPhone access. iOS compatibility remains required, but physical-device
> validation is a later compatibility and release gate rather than the routine
> development path. This clarification supersedes the phone-first recommendation
> below for the keystone prototype phase only; the final production renderer must
> still be validated on its oldest supported physical iOS device.

**1. Recommended direction**

Build real 3D glass vessels and use a GPU fluid solver for moving liquid, pouring, impact, and settling. Keep Swift for the app, persistence, and puzzle logic; replace the SwiftUI board artwork with a dedicated 3D rendering surface. Start by evaluating Metal directly, with RealityKit as a possible scene layer, against Unity with Obi Fluid in a short prototype comparison.

The recommended production architecture has three independent responsibilities:

| System | Owns |
|---|---|
| Puzzle engine | Exact quantities, legal actions, interaction outcomes, hints, undo, completion, and level generation |
| Fluid simulation | Liquid motion inside moving vessels, streams, collisions, splashes, and settling |
| 3D presentation | Glass, reconstructed liquid surfaces, lighting, camera, vessel choreography, sound, and accessibility |

This would be actual simulated liquid motion during play. Resting vessels can use exact equilibrium surfaces and stop simulating after settling. There is no benefit to continually simulating every particle in a still board.

Keep two explicit rule families: **Classic**, preserving today's sorting puzzles with controlled fluid behavior, and **Fluid Lab**, introducing density, mixing, and other physical interactions. A later sandbox can make continuous physical outcomes authoritative, including spills and partial pours. That is a different game mode with different guarantees.

This plan supersedes the earlier roadmap's preference for equal-height units and postponing real simulation until a sandbox. The new requirement is equal **volume**, variable height, and simulated motion in the main presentation. It retains the useful separation between puzzle state and visual state.

**2. What the current code implies**

The reviewed implementation is a native SwiftUI game:

- [Vial.swift](</Volumes/Code Work/xCode work/Vials/Vials/Game/Vial.swift>) stores an integer capacity and a bottom-to-top array of fluid identities.
- [LiquidContainerProfile.swift](</Volumes/Code Work/xCode work/Vials/Vials/Materials/LiquidContainerProfile.swift>) assigns each unit the same pixel height. It does not integrate vessel volume.
- [VialView.swift](</Volumes/Code Work/xCode work/Vials/Vials/Components/VialView.swift>) draws clipped layers, gradients, and glass outlines. Adjacent identical fluids already merge visually through `LiquidLayerStack`.
- [VialSlot.swift](</Volumes/Code Work/xCode work/Vials/Vials/Components/VialSlot.swift>) uses a fixed 34-degree pour tilt; the vessel does not travel to the receiving vessel.
- [PourStreamView.swift](</Volumes/Code Work/xCode work/Vials/Vials/Animations/PourStreamView.swift>) draws a quadratic curve and decorative droplets. These do not solve fluid pressure or collisions.
- [FluidMaterial.swift](</Volumes/Code Work/xCode work/Vials/Vials/Game/FluidMaterial.swift>) contains appearance and timing parameters, without physical density, viscosity, or interfacial properties.
- [ContentView.swift](</Volumes/Code Work/xCode work/Vials/Vials/App/ContentView.swift>) applies the complete logical transfer before its animation, supports up to three active pours, and permits multiple incoming pours into a destination.
- [VialLevelGenerator.swift](</Volumes/Code Work/xCode work/Vials/Vials/Game/VialLevelGenerator.swift>) shares the current top-color sorting assumptions. Its state key treats containers with the same contents, capacity, and rule as interchangeable.

The Xcode project declares iPhone, iPad, macOS, and visionOS-related targets. Platform declarations are not evidence that the proposed renderer performs acceptably on those devices. Preserve existing progress and level identities; choose a concrete minimum device during the prototype.

**3. Technology and solver choice**

Swift is not the limiting factor. SwiftUI shapes are the current presentation limitation; GPU work can run in Metal compute shaders while Swift orchestrates the app.

| Route | Strength | Main cost or uncertainty | Recommendation |
|---|---|---|---|
| Swift + Metal/MetalKit | Full control over simulation buffers, liquid surfaces, and glass compositing; retains existing app | Custom rendering and fluid engineering | Default for Apple-focused release |
| Swift + RealityKit + Metal compute | Existing 3D scene, asset, lighting, and entity infrastructure | Must prove liquid-within-glass rendering and material interfaces meet the art target | Evaluate as a scene layer |
| Unity + Obi Fluid | Existing particle solver, fluid meshing, material tools, and editor workflow | Platform testing, integration or C# port of game systems, rendering customization, dependency maintenance | Strong comparison candidate, especially for future Android/PC |
| Unreal + Niagara Fluids | Existing fluid-effects tooling and a rich 3D pipeline | More infrastructure than this small game needs; target-device performance remains unproven | Reconsider only if the product becomes desktop-first |
| Further SwiftUI/Canvas effects | Low migration cost | Does not deliver the requested volumetric fluid behavior | Accessibility or legacy fallback only |

RealityKit's `LowLevelMesh` supports updates from Swift or Metal compute shaders. That enables custom simulation integration; it is not a built-in volumetric liquid solver. Apple now marks SceneKit deprecated, so it should not be the basis of this major rebuild. [Apple LowLevelMesh](https://developer.apple.com/documentation/RealityKit/LowLevelMesh), [Apple SceneKit documentation](https://developer.apple.com/documentation/scenekit/).

Obi provides particle simulation and fluid surface meshing. Its backend and material documentation are useful for an evaluation, but they do not establish a frame-rate guarantee for this game's glass, layers, and target devices. Pin and test the exact Unity/Obi/render-pipeline combination before adopting it. [Obi backends](https://obi.virtualmethodstudio.com/manual/7.0/backends.html), [Obi fluid rendering](https://obi.virtualmethodstudio.com/manual/7.0/fluidrendering.html). Unreal's liquid tools use a particle/grid FLIP approach. [Epic fluid overview](https://dev.epicgames.com/documentation/unreal-engine/fluid-simulation-in-unreal-engine---overview).

For a custom solver, prototype **Position Based Fluids (PBF)** first: particles interact through density constraints, producing approximately incompressible liquid rather than a collection of bouncing balls. It is a practical starting point for interactive animation. It still needs wall treatment, viscosity, interfacial behavior, and surface reconstruction. [Macklin and Müller, Position Based Fluids](https://mmacklin.com/pbf_sig_preprint.pdf).

If PBF cannot maintain convincing volume or avoid rubbery movement within budget, compare **DFSPH**, which explicitly controls density and velocity divergence. Use a separate multiphase formulation for different densities; changing particle weights alone is not a complete multiphase solver. Research implementations provide useful reference cases, not a ready-made Metal backend. [Bender and Koschier, DFSPH](https://dankoschier.github.io/resources/papers/BK17.pdf), [SPlisHSPlasH project](https://github.com/InteractiveComputerGraphics/SPlisHSPlasH).

**FLIP/APIC** remains the alternative for a higher-fidelity desktop path. These combine moving particles with a grid and pressure solve. APIC improves the transfer of motion between particles and grid; it does not remove the grid's engineering and memory costs. [Disney, The Affine Particle-In-Cell Method](https://www.disneyanimation.com/publications/the-affine-particle-in-cell-method/).

Do not replace the current effects with thousands of SpriteKit/rigid-body circles and call that fluid simulation. Conversely, a shallow-water height field is useful for a resting surface but cannot represent an overturning pour or separated droplets.

**4. Vessel geometry and equal-volume units**

Create one vessel asset definition containing an exterior mesh, interior cavity, wall thickness, lip and spout locations, upright volume table, collision representation, and calibrated capacity. Rendering, filling, and collision must derive from the same cavity.

Begin with surfaces of revolution: a rounded test tube, conical flask, bulb flask with a narrow neck, and wide beaker. A radius profile is easy to edit and can generate both glass surfaces. Add asymmetric spouts next. Defer connected chambers, handles containing liquid, and narrow internal passages until their collision and air behavior are supported.

For an upright vessel with interior horizontal cross-sectional area A(z):

`V(h) = integral from bottom to h of A(z) dz`

For an axisymmetric vessel, `A(z) = pi * r(z)^2`. Precompute the cumulative volume table and invert it to find height for a specified volume. For arbitrary cavities, integrate horizontal mesh sections or a sufficiently resolved voxel representation.

One unit has the same nominal volume U across the board. The kth unit occupies the height interval between `inverseV((k-1)*U)` and `inverseV(k*U)`. A wider section produces a shorter band; a narrow neck produces a taller band. For example, 10 mL occupies 1 cm at a constant area of 10 cm², and 5 cm at 2 cm². Equal volumes of different-density liquids still occupy the same space under the initial incompressible model; their masses differ.

Choose vessel dimensions so the intended fill line contains `capacity * U`; reserve headspace above it. Do not normalize every differently sized vessel to an unrelated unit volume. Screen zoom must change only the camera, not the simulated dimensions.

When a vessel tilts, an upright lookup table is insufficient. In static equilibrium the free surface is perpendicular to gravity. Determine the plane that encloses the required volume in the transformed cavity; derive where that plane reaches the lip. During acceleration and rotation, simulate the transient slosh rather than attaching the fluid to the vessel's local up direction. Meniscus curvature is a separate small-scale effect.

Use a signed distance field or an equivalent detailed cavity boundary for collisions. A single convex hull would close off a hollow vessel. Resolve the narrowest neck with enough samples and use substeps or swept collision handling to prevent leakage through moving walls. World-space simulation with moving-wall velocities is the initial recommendation; a local-space solver requires the corresponding inertial forces.

Show subtle, unevenly spaced volume graduations and exact quantities on selection. Shape variation alone changes appearance and measurement difficulty; it does not change the underlying sorting puzzle unless shape affects an action, outlet, or capacity rule.

**5. How the animation should look and work**

Use a steady, slightly elevated camera so the glass rim, wall thickness, and fluid surfaces are visible. Vessels are fully 3D even when the board interaction remains a simple tap. Avoid a large camera swing on every move.

The pour should be one coordinated sequence:

1. **Lift and travel:** raise the source out of its slot, move it above the receiving opening, and clear adjacent vessels. Use a smooth path with continuous velocity and restrained acceleration. The liquid responds with a small lagging slosh.
2. **Align and tilt:** rotate around a deliberate grip point. The lip's actual 3D position drives the pour. Start flow when liquid reaches the lip, rather than at a fixed tilt angle.
3. **Transfer:** increase tilt as the source empties. Gravity forms the falling stream; the destination begins filling only after travel time. Impact produces a local depression, outward ripples, and restrained splash droplets.
4. **Cut off:** rotate back early enough to account for liquid still in flight. The stream narrows, breaks, and leaves a final droplet when appropriate.
5. **Return and settle:** return along a clear path, ease onto the board, and let residual waves decay. The destination can settle while the source travels home.

Use a controller for vessel motion, not a wholly uncontrolled rigid body. Estimate its trajectory and cutoff from the lip, receiving aperture, fluid parameters, and transfer budget. Simulated liquid still determines the detailed motion. Density alone does not make a stream fall faster under gravity; viscosity, exit velocity, geometry, and surface tension change its appearance.

Prototype roughly 0.9–1.6 seconds for a normal one-unit move, with additional transfer time for larger amounts and thick liquids. These are art-direction targets, not measured physical constants. Provide faster repeated play and Reduce Motion. Avoid arbitrarily speeding the solver clock to shorten animation, which can change its behavior.

Keep a volume ledger during a pour: source + in-flight + destination + any explicit spill equals the starting volume. Never drain one source representation and independently emit an unaccounted second copy into the stream. Droplet particles must either own transferred volume or be explicitly negligible visual effects. In Classic, the choreography should capture the stream and splash back into the receiving vessel; gameplay spills belong in a later challenge mode.

The hardest fidelity conflict is pouring exactly one top layer from a tilted multicolor vessel: real liquids can entrain neighboring layers or leave films behind. Classic therefore needs controlled interfacial behavior and metering. First prove a clean single-liquid pour, then a two-color interface. If exact layer transfer needs visible snapping or hidden bulk teleportation, the prototype has failed its visual gate. An explicitly metered spout is a possible later design choice, but it would change the vessel design and must be evaluated as such.

Initially serialize pours. Later restore disjoint simultaneous pours only after path planning and GPU capacity are proven. Two sources pouring into one receiver need shared simulation and a defined interaction order; they cannot be treated as independent effects.

**6. Rendering quality is a separate workstream**

The solver produces positions and velocities, not beautiful liquid. Budget explicit work for surface reconstruction and glass:

- Reconstruct a smooth continuous surface from particles. Compare a screen-space depth/thickness method against a generated isosurface mesh. Test thin streams, narrow necks, silhouettes, and temporal stability.
- Preserve fluid-material interfaces. Rendering only the outer surface with one averaged color would destroy the game's layered appearance. Multicolor transparent rendering must be in the early prototype.
- Render actual inner and outer glass walls, a rounded rim, soft contact shadows, and a stable studio-light environment. Control transparent depth ordering so rear glass does not incorrectly cover the liquid.
- Use angle-dependent reflection/refraction and thickness-dependent absorption. Deeper liquid can appear darker while preserving recognizable puzzle colors. These are optical models, not opacity gradients attached to a rectangle. [Physically Based Rendering: reflection and transmission](https://www.pbr-book.org/4ed/Reflection_Models/Specular_Reflection_and_Transmission), [transmittance](https://pbr-book.org/4ed/Volume_Scattering/Transmittance).
- Approximate caustic light patterns and very thin wetting films initially. Fully resolving these effects is unnecessary for the first mobile release.
- Tune meniscus, bubbles, foam, and droplet breakup by material. Avoid a universal bubbling or glowing effect on every liquid.
- Drive sound from flow and impact, with a small return-to-board haptic. Keep non-color identifiers available in the UI, rather than distorting liquid shading to carry every accessibility cue.

A mobile real-time renderer can target convincing physical appearance, but offline-film-quality glass and fully resolved fluid/air interfaces are outside this estimate.

**7. Game state, simulation, and undo**

Extract gameplay transitions from `ContentView` into a renderer-independent core. A move yields a transaction containing the pre-state, approved amount, deterministic post-state, and presentation events. Commit logical state once; animate the transaction; cancel presentation safely on restart, app suspension, or navigation.

Keep integer base-volume quantities for Classic. For Fluid Lab, extend the model with material identity, composition quantities, phase, and any explicit temperature/timer state. Store those quantities as integers or bounded rational values so hints do not depend on rounding floating-point concentrations. Keep optical color separate from chemical composition.

At animation completion, reinitialize the resting representation from exact canonical volumes only when the physical presentation is already within a small error tolerance. Correct small drift smoothly during settling. A visible amount correction is a bug to fix, not an acceptable end-of-pour technique.

GPU simulation need not be bit-identical across devices. A fixed timestep improves stability but does not guarantee determinism across hardware. Puzzle rules and quantities must be deterministic. Undo restores a snapshot and rebuilds the resting liquid; it does not numerically reverse fluid motion. An exact mid-pour sandbox replay would require additional simulation-state recording.

Classic also cannot simultaneously retain arbitrary persistent color stacks and obey unrestricted real-world mixing and buoyancy. Treat its colors as stable, deliberately constrained phases. Fluid Lab can allow sinking and mixing, but levels must begin in a physically compatible canonical settled state.

**8. Gameplay extensions and incremental estimates**

The following are design proposals inspired by real phenomena. Estimates are additional engineering person-weeks **after** the base 3D simulation and shared interaction framework exist. Each includes one mechanic, focused validation, and a small authored teaching set, not an entire generated campaign. Visual effects and rule abstractions are distinguished explicitly.

| Mechanic | Possible puzzle | Physical behavior and intended abstraction | Added effort |
|---|---|---|---:|
| Density and immiscibility | Pour a heavy liquid through a lighter one; assemble a target density stack or drain the bottom phase | A dense plume sinks and the light phase rises. Limit the first set to two or three immiscible materials; resolve a deterministic settled order | 3–5 weeks |
| Color mixing and recipes | Make two units of purple from one red and one blue; later require a 2:1 recipe | Carry composition through swirling flow, then resolve an authored mixture. Unequal amounts produce a different recipe | 4–7 weeks |
| Viscosity and neck restrictions | Warm a thick fluid or route it through a wider outlet | Thick liquid flows slowly; a complete ban through a narrow opening is an explicit game rule, not ordinary viscosity alone | 2–4 weeks |
| Graduations and calibrated doses | Fill an irregular flask to a mark or dispense a half-unit using a tool | Use volume geometry and fixed permitted doses. Freehand analog pouring belongs in a separate skill mode | 1–3 weeks |
| Bottom taps and decanting | Remove the heavy bottom phase through a tap, or pour the lighter top phase away | Requires different outlet rules and shape-aware content; pairs especially well with density | 2–4 weeks |
| Connected vessels and siphons | Equalize levels or prime a siphon to transfer around an obstacle | Communicating-vessel pressure or a primed, continuous siphon path; use authored tool states before full pipe/air simulation | 4–7 weeks |
| Surface tension and wetting | Select a coated spout or capillary channel to retain or route droplets | Beading, wall adhesion, and narrow-tube capillary behavior; use finite tool rules for solvable puzzles | 3–6 weeks |
| Emulsions and separation | Shake two immiscible fluids into a cloudy emulsion, then allow or trigger separation | Temporary dispersed droplets differ from a truly dissolved mixture; settling is a defined action or turn event | 4–7 weeks |
| Sedimentation and filtration | Settle suspended solids and route the clear liquid through a filter | Filters remove specified particles. An ordinary filter cannot separate dissolved red and blue dyes | 3–6 weeks |
| Foam and dissolved gas | Reserve headspace before adding a fizzing component, then release gas with a vent tool | Gas occupies space without becoming extra liquid inventory; initial collapse timing is move-based | 4–7 weeks |
| Heating, cooling, and phase change | Melt a plug, reduce viscosity, freeze a route, or collect condensed vapor | Use discrete temperature/phase states first; coupled heat transfer and expanding solids are later work | 5–9 weeks |

Density, viscosity, and miscibility are independent properties. A heavier water-based dye can sink temporarily and still mix later; “heavy” does not imply a permanent bottom layer. Multiphase research explicitly distinguishes phase transport and mixing models. [A Divergence-free Mixture Model for Multiphase Fluids](https://diglib.eg.org/bitstream/handle/10.1111/cgf14102/v39i8pp069-077.pdf).

For familiar red + blue = purple gameplay, define an intentional palette and recipe table. Do not average display RGB values and call that accurate liquid chemistry. Dye appearance depends on absorption, concentration, and viewing thickness; mixing colors also need not create a new chemical substance. Preserve quantity: one red unit plus one blue unit produces two units of mixture under the initial additive-volume approximation. Thermal expansion and mixing-related volume contraction would require a later mass/density model.

The most valuable first sequence is **density + bottom taps**, followed by **mixing + calibrated doses**. These change strategy, use the new 3D presentation well, and can be taught without real-time pressure. Viscosity alone is mostly animation variety unless a tool, outlet, or time-budget rule makes it strategically relevant.

**9. Solver, level design, and progression changes**

Build a shared interaction framework before enabling new mechanics. Budget **2–4 engineering weeks** for material/recipe definitions, finite transition rules, state versioning, and solver integration, separate from the per-mechanic estimates above.

Every mode must share one legal-action and state-transition definition with the hint solver. Density and mixing need explicit permission to pour onto a different material; today's same-color destination rule prevents those interactions entirely.

Define a stable transition sequence, for example transfer → eligible mixing → phase separation → explicit turn effects → completion. The exact order is a gameplay choice and must be taught and tested. Density ties need a stable rule. Reactions must terminate rather than repeatedly transform back and forth.

Revisit existing solver assumptions:

- A completed vial may become a useful ingredient source; the current prune that avoids moving a complete vial into an empty one may no longer be valid.
- A vial's geometry/outlets become part of its state class when they affect legal actions. Otherwise canonicalization could incorrectly equate a round flask and a bottom-tap vessel.
- Mixing creates irreversible actions. Reverse-scrambling from solved boards is not sufficient without valid inverse rules. Use authored teaching levels, forward-valid solution witnesses, and bounded solver validation.
- Completion may mean a target recipe, quantity, or phase order, rather than one full vial of a single color. The helper cup and receive-only valve need explicit rules for every mode.
- New concentrations, timers, and tools enlarge the search space. Start with few materials and finite recipes. Do not enumerate arbitrary continuous mixtures in the normal solver.

Version rule sets and level identities for new modes, keeping Classic records intact. Label a result as exact minimum only when proven; a feasible solution length is an upper bound, and an exhausted search budget is not proof of a dead end.

Introduce each mechanic through roughly 6–10 authored levels before generated content. Use one interaction family at a time, then carefully chosen pairs. Include a predicted settled result before committing an unfamiliar action. Keep undo free and avoid wall-clock deadlines in the relaxed mode.

**10. Phases, deliverables, and decision gates**

Estimates assume one experienced graphics/simulation engineer who can also work in Swift, with part-time 3D/material art support. They are planning ranges, not measurements or delivery commitments. A developer learning fluid solvers and GPU rendering should expect longer.

| Phase | Concrete deliverable and completion gate | Engineering effort |
|---|---|---:|
| A. Feasibility comparison | Same two vessels and pour scenario in a minimal native prototype and an Obi evaluation; include two colors, glass, a narrow neck, and on-device captures. Choose engine/solver from evidence | 2–3 weeks |
| B. Geometry and game boundary | Four calibrated vessel shapes, cavity collision data, volume inversion, renderer-independent move transactions, unchanged Classic solver behavior | 2–3 weeks |
| C. Production simulation | Moving boundaries, stable bulk liquid and streams, thin/thick profiles, layered-phase treatment, volume accounting, sleep/wake behavior | 4–7 weeks |
| D. 3D visual and motion polish | Liquid surface reconstruction, glass/material interfaces, lift/pour/return controller, splash/settle, sound and haptics | 4–6 weeks |
| E. Whole-game integration | Classic boards, variable capacities, helper cup growth, valves, hints, undo, restart, lifecycle handling, accessible presentation | 2–4 weeks |
| F. Device and release validation | Sustained performance tuning, quality tiers, visual regressions, multiple layouts, playtesting, feature-flag rollout | 3–5 weeks |
| **Base total** | Production 3D Classic conversion, without new interaction campaigns | **17–28 engineering person-weeks** |

Add approximately **3–6 art person-weeks**, overlapping development, for vessels, lighting, materials, and polish. With **25–35% engineering contingency**, plan approximately **22–38 engineering weeks**, or around **5–9 months** for a primarily sequential single-engineer effort. A small experienced team can overlap geometry, art, and integration, but the simulation and rendering gates constrain compression. Full visionOS spatial presentation, Android porting, and continuous sandbox simulation are excluded.

The first 2–3 weeks should produce a decision-quality experiment, not a finished replacement. A convincing integrated vertical slice is a more realistic **6–10 engineering-week** milestone, drawing selected work from phases A–D. Re-estimate the remainder at that point.

If Unity wins the comparison, its solver may reduce custom simulation work, but app integration or a core-game port offsets some of that saving. Do not assume a faster total until the prototype measures fluid rendering and a migration inventory covers persistence, solver behavior, accessibility, and platform features.

After the base conversion, a first Fluid Lab release with the shared framework, density, and mixing adds roughly **9–16 engineering weeks before contingency**. Bottom taps or dosing would add their own smaller increments. A continuous sandbox with meaningful spills, manually controlled tilting, and resumable physical state is a separate **8–16+ week** investigation after the base; unrestricted thermodynamics and arbitrary reacting liquids are not included.

**11. Performance and quality gates**

Choose the oldest supported physical phone first. Target 60 fps, meaning a total frame budget of 16.7 ms, with an initial engineering allocation of about 4 ms for simulation and 6 ms for fluid/glass rendering. These are targets to validate, not predicted timings. Measure frame-time percentiles, GPU memory, sustained heat, and battery impact over at least 15 minutes of repeated play. A Mac or simulator result cannot stand in for a phone benchmark.

Benchmark several resolutions, for example 4k, 12k, and 30k active fluid particles **across the active pour scene**, rather than promising a fixed count per vial. Resolution must also resolve the neck and stream; particle count alone is not a quality metric. Keep buffers on the GPU, avoid routine readbacks and per-frame allocation, and reduce transparent overdraw before cutting visually important fluid detail.

Simulate the source, destination, stream, and relevant interactions; put other vessels to sleep. Start with one pour, then profile up to the existing three. Provide quality tiers that lower surface resolution and decorative effects while preserving quantities and rules. A 30-fps compatibility mode is possible if the minimum device cannot meet the 60-fps gate, but it should be an explicit product decision.

Acceptance checks should include:

- Analytic cylinder/cone volume tests and sampled arbitrary-shape tests; proposed equilibrium fill-volume error below 0.5%, with no cumulative logical inventory error.
- A proposed transient volume-error gate below 1% of transferred volume, plus a stricter visual check for narrow-neck height errors. Repeated pours must not visibly inflate, deflate, or snap on completion.
- No wall leakage, unintended streams from dry lips, clipping through neighbors, or stream detachment across slow-motion inspection of empty, near-empty, and near-full pours.
- Distinct fluid interfaces through front and rear glass, no cloudy color averaging in Classic, and no visually apparent gain/loss when particles become a sleeping surface.
- Matching final puzzle outcomes across quality tiers, frame rates, device rotations, interruptions, undo, restart, and app background/foreground transitions.
- The current generated-level validator still passes for Classic; new rule modes have separate authored fixtures and solver checks.
- Comfortable repeated play: readable quantities in bulb and neck sections, a fast animation option, Reduce Motion, non-color identification, and appropriate VoiceOver descriptions.

Proceed to broad implementation only when the prototype can demonstrate a narrow-neck pour, a believable two-color interface, and glass rendering within the chosen device budget. If it fails, revise the solver, renderer, or supported-device target before porting the rest of the game.

The first release scope should be four genuinely 3D vessel shapes, equal-volume filling, convincingly simulated controlled pours, and the existing Classic rules. Density and mixing then become designed expansions on a stable foundation.
