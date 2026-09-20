# Visible mixing transitions

September 20, 2026. The prior vessel/density/completion work is committed and pushed as `9c86721` on `codex/fluid-lab`. Authenticated GitHub ownership and the matching remote commit were verified. This mixing prototype is a subsequent local change, not yet committed or pushed.

## Behavior

Pressing Mix now feeds both inputs into the output along short pumped arcs, folds the two colors through each other, and gradually blends them into the recipe's result. Classic draws colored streams and ribbons; 2D and 3D move the existing particle identities through a controlled vortex. The transition lasts 2.8 simulation seconds and follows the selected pace. Density modifiers retain their immediate behavior.

Mixing is one transaction. The board keeps the last committed state while the animation runs, blocks duplicate activations and other moves, and commits the exact recipe once at completion. Undo restores both original inputs and pigments. A checkpoint taken during mixing contains the pre-mix board, so relaunch does not restore half a transformation. Pause/background suspension stops elapsed time; Reset cancels the animation. Reduced Motion removes the vortex agitation. Existing exact material quantities and recipe rules remain unchanged.

The particle paths finish at exact prepared output samples. 2D targets use a relaxed final fill; 3D targets use its existing canonical packing. At completion there is no extra solver-driven reseed of successful arrivals. Color interpolation preserves the normal pigment/density palette at both ends. The 3D shader uses the existing depth/thickness passes, and mixing does not run the full particle solver. Idle planar decoration excludes the active mixer vessels to avoid old highlights in emptied inputs.

This is an authored apparatus animation, not a chemical or general multiphase solver. The input arcs represent pumped transfer; the input vessels stay in place.

## Validation

- Release macOS and signed generic-iOS builds pass. No Swift compiler warnings remain; Xcode reports only its usual no-AppIntents metadata note.
- All 48 animated mixer fixtures pass: every authored mixer activation in Mixing and Crossover, across Classic, 2D Fluid and 3D Fluid. Checks cover deferred single commit, particle inventory and finite positions, duplicate activation, pause and suspension, checkpoint state, final particle continuity, full undo, cancellation/reset, and Reduced Motion. The three introductory recipes also pour their finished mixtures to the target and solve afterward in all three modes. See [validation log](validation.log).
- Existing session validation passes all 15 experimental levels with explicit immediate activation for the model-oriented routes. The dedicated mixing suite exercises the new animated path.
- Actual Mac UI: filled both Warm blend inputs in 3D, then exercised Mix, pause/resume, exact two-unit orange output at three moves, and Undo back to the two original inputs at two moves in each of the three presentations. Intermediate screenshots were visually inspected. `caffeinate -di` ran during the UI checks.
- No physical iPad installation or battery/performance measurement was attempted; Eddie said it was unavailable. Signed iOS compilation is not a device test.

Run:

```sh
bash Scripts/validate_mixing.sh \
  build/round-vials/DerivedData/Build/Products/Release/VialsFluidLab.app/Contents/Resources/default.metallib
```

## Preview

[Classic ribbons](classic-mixing.png), [2D vortex](2d-mixing.png), [3D input transfer](3d-inputs.png), [3D folding colors](3d-mixing.png), [3D blended result](3d-blended.png).

The Mac is left at Warm blend in 3D with the two mixer inputs filled; press Mix to review. Compare the other presentations by undoing the mix and switching the presentation before pressing Mix again.

## Lift-responsive floor shadows (September 20)

Classic, 2D Fluid and 3D Fluid now share a pose-driven contact-shadow response. Each footprint follows its vial's horizontal floor projection, shrinks and fades with elevation, and restores on landing. Concurrent sources use their own poses; pausing requires no separate shadow clock. Metal now uses per-vial shadow samples instead of the two fixed study shadows, with the standalone renderer binding the same input. Planar shadows use an elliptical radial gradient without a blur render pass.

Validation: Mac Release and signed generic iOS Release builds passed. Offscreen Classic/3D rest, half-lift and full-lift images were inspected; Metal board and standalone composition completed successfully. A four-unit tube's shadow radius decreased from 0.564 at rest to 0.279 at half lift and 0.205 at full lift. Mac 2D live pour/pause/resume checked with caffeinate; iPad hardware remains untested. These changes are local and uncommitted.

### Shadow visibility correction

The first lift-shadow revision was too faint. Restored a stronger dark core, broadened each footprint to match the vessel body, and reduced the opacity loss during lift. The planar floor has a soft local light patch around the dark core for contrast on the nearly black background. In Metal, contact darkening now applies after the background vignette mix, so outer vials on wide boards retain their shadows. New fixed rest/half/full-lift renders visibly show the shadows and preserve shrinking; board and standalone Metal composition passed.
