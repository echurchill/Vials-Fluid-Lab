# Readable overlapping vials

September 15, 2026. Follow-up to the shared-receiver investigation. Based on the current Classic/2D/3D rendering code and the existing Prototype17 Classic capture. No new visual treatment has been implemented or benchmarked.

## Recommendation

Use consistent foreground/background separation with a different material treatment in each presentation. Keep the foreground liquid and its level immediately readable. Let the glass communicate depth through rim reflections, controlled transmission and modest distortion of what lies behind it. Avoid abruptly making the entire vessel opaque whenever its silhouette touches another one.

Plan paths that prevent actual vessel intersection first. Screen-space overlap remains natural and should look intentional. The shared-receiver approach positions should also define stable visual ordering in Classic/2D; 3D should use camera-space depth. Do not flip order because a source crosses the screen midpoint. A change in order should happen at a physically coherent crossing, ideally outside the overlap.

## What the existing code does

**Classic:** `LabClassicBoardView` draws stationary vials and then moving vials. Each vial is drawn as a unit, but the empty glass has only a faint fill and the liquid is partly transparent. Rear lines can remain visible through the front vessel. Two moving vials follow the supplied array order, without an explicit depth/approach policy.

**2D:** `LabFluid2DView` draws every cavity, then liquid grouped by owner index, then every glass outline. This is not a back-to-front ordering of complete vials. A rear outline can therefore be drawn across foreground liquid. Blue's lower opacity makes competing layers particularly visible. Idle decoration is a separate overlay in `LabPlanarSurface`; it also needs the same overlap masks so rear details cannot float over front glass.

**3D:** `LabBoardRenderer` first reconstructs a liquid scene, then draws depth-tested glass shells. `labGlassFragment` samples that liquid/background image with a normal-based offset, adds reflection and tint, and outputs alpha 1. The transparency is synthesized through sampling; changing alpha alone would not fix it. All shells sample the same scene, which contains no other glass shells. A nearer shell therefore cannot refract the completed rear shell's rims and reflections. The global nearest-liquid surface also does not retain all hidden liquid layers needed for full multi-layer refraction.

## Treatments to compare

| Presentation | Recommended first treatment | Optional richer treatment |
| --- | --- | --- |
| Classic | Draw each whole vial in stable order. Suppress rear lines beneath foreground liquid; lightly smoke the empty foreground cavity. Add a narrow separation shadow and crisp front rim. Keep the front liquid colors substantially opaque. | A restrained highlight that travels with the rim. Refraction is probably unnecessary for this style. |
| 2D Fluid | Keep translucent fluid, but draw complete vial layers in stable order and suppress rear outlines/details where they compete with foreground fluid. Preserve a clear front silhouette. | Render the rear imagery into a texture and slightly distort/soften only the part seen through the front cavity. Stronger near curved edges and the foot, weaker through the center. Keep the physics entirely 2D. |
| 3D Fluid | Make glass composition aware of the rear vial imagery and depth, retaining the existing normal-based reflections and rim highlights. | Controlled refraction of the rear vial through the front wall, with modest attenuation through foreground liquid and thickness-based distortion. Start with the two overlapping layers required by two active pours. |

For an “opaque” comparison, block the rear image before drawing the foreground vial's own liquid and glass. Do not paint an opaque shell over that vial's own contents. This gives a useful readability baseline without hiding its fill level.

For the lens treatment, bend the image seen through the front vial; do not deform the rear vial's actual geometry, physics or hit target. Leave the uncovered part of the rear vial unchanged. Fade any adaptive contrast treatment smoothly so materials do not flash when overlap begins or ends. Persistent modest material properties are preferable to a large opacity switch.

## Liquid Glass

Apple's material provides useful visual inspiration: edge lensing, highlights and controlled background transmission. Apple describes the actual system Liquid Glass material as a controls/navigation layer and advises against applying it throughout content. Its shared containers can also merge or morph nearby glass shapes. Independent game vessels must retain separate identities.

Use a custom game-glass treatment for the board, with the exact masks, color preservation and depth behavior the game requires. The system effect may remain appropriate for controls. This is a design recommendation, not a technical prohibition against experimenting with a custom-shaped system effect.

Sources: [Apple materials guidance](https://developer.apple.com/design/human-interface-guidelines/materials), [applying Liquid Glass to custom views](https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views), [Meet Liquid Glass](https://developer.apple.com/videos/play/wwdc2025/219/).

## Implementation and performance

Start with correct layering and the low-cost masking treatment in Classic/2D. The 2D lens version adds an offscreen image and a shader/compositing pass; it does not require changing the fluid solver. Render rear imagery once where practical and restrict distortion to affected regions. Measure compositing cost independently of worker solver time.

For 3D, compare a small number of depth-aware compositing layers. The front glass needs a rear-color image that includes rear shells and their contents. Keep glass, its own liquid and unrelated rear liquid distinct to avoid refracting or tinting the wrong layer twice. Additional texture passes and bandwidth require iPad profiling; no frame-rate or battery improvement is claimed. Full ray tracing is not necessary for the proposed stylized treatment.

Keep a readable fallback with no distortion. Respect Reduce Transparency by suppressing transmitted rear imagery while preserving the foreground vessel's own liquid; Reduce Motion should suppress decorative motion without obscuring the game action. Labels and source/destination cues should stay crisp and outside the refracted content.

## Visual acceptance checks

Compare current appearance, stronger occlusion and the restrained lens treatment on identical fixed poses and recorded motion. Include empty/full foreground vials, every fluid color (especially translucent blue), differently colored rear liquid, narrow necks, broad bodies, two same-side sources, both directions of travel, portrait/landscape and the 3D camera angles.

Check that rear outlines do not become false foreground boundaries; overlapping colors do not appear to form a new gameplay color; fill levels remain easy to judge; rims never merge; rear markings soften only inside the overlap; streams remain visible at the shared mouth; caps, hints and idle effects obey the same ordering; and no material or ordering change flashes at the overlap boundary. Verify true geometric collisions are absent rather than hidden by a material effect.

My preferred first comparison is clean, slightly smoked Classic glass; softly refracting 2D glass; and depth-aware refracting 3D glass. Develop the stable layer/approach policy alongside the shared-receiver motion work, then add the richer optical effects after that behavior is correct.
