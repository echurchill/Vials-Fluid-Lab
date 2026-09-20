# Density settles during the pour

September 19, 2026. Local implementation for review; not committed or pushed.

Incoming medium liquid descends through light liquid and joins above existing medium or heavy liquid. Heavy descends through medium and light and joins above existing heavy. Equal-density layers retain their existing bottom-to-top order even when their pigments differ. Light joins above the existing layers. This applies to Density and Crossover in Classic, 2D Fluid and 3D Fluid.

## Implementation

The game still commits exactly the same stable density ordering. Shared presentation helpers calculate the receiving bands from fractional incoming volume, retaining resident equal-density material below the arrival.

- Classic draws a sinking ribbon and progressively grows the receiving band. The first short descent uses a smooth visual front; lighter bands rise as incoming volume joins beneath them.
- 2D droplets remain outside the bulk until reaching their density interface. They pass through lighter bulk particles, then join the accumulating band. Resident boundaries move upward with joined volume. Incoming color is drawn after the resident layers to keep the submerged path visible.
- 3D tracks joined particles after the preceding GPU command completes. Receiving bands grow from those particles, while a bounded per-step downward guide lets arrivals cross lighter layers instead of snapping to their final band. Shader pressure iterations share the same previous-step anchor. The existing thickness pass also supplies a muted glimpse of incoming color through the resident surface; the front-surface owner prevents this cue appearing through a foreground source vial. No new render pass or particle-budget increase.

This is controlled density-aware presentation using the existing solvers, not a general multiphase fluid simulation. Logical quantities, targets, hints, saves and undo remain authoritative. The existing 5% capture-correction allowance is unchanged. Sorting's concurrent lanes and Mixing's ordinary pour behavior do not use the new density constraints.

## Validation

- Release macOS and signed generic-iOS builds pass.
- Seven trajectory fixtures run in both particle modes: heavy through light; medium above heavy; medium above medium; heavy above heavy; light floating; two-unit heavy pour; Crossover medium. They verify the equal/heavier boundary, visible intermediate descent, bounded per-frame movement, at least 94% in the target layer before cleanup, exact committed state, and 3D pause stability. Every fixture actually reached 100% in its target band before cleanup. This is a count within the target height tolerance, not a claim of exact simulated fluid volume.
- Complete authored routes for all five Density and all five Crossover levels pass in both particle modes, including apparatus operations and full undo. See [trajectory and route log](density-trajectories.log).
- Sorting concurrent-pour regression passes Classic/2D/3D shared receivers, overlapping lanes, pause/suspend, checkpoint, partial completion, undo/reset, and the Level 16 held-source/return fixtures. See [concurrent log](concurrent.log).
- Model validation passes all 31 levels. Session validation passes all 15 experimental levels, hints, Classic completion, undo and four-lab persistence.
- Actual Mac UI: reset and complete Heavy landing (light first, then heavy) in all three presentations. Completion leaves vial, card, information and toolbar positions unchanged. `caffeinate -di` ran during testing.
- Screenshots of Classic, 2D and 3D intermediate states were inspected. See [Classic](medium-classic.png), [2D](medium-2d.png), and [3D](medium-3d.png).

Physical iPad installation, appearance and performance checks remain pending availability; a successful iOS build is not a device test. No battery or performance improvement is claimed from these functional runs.

Run the regression from the repository root:

```sh
bash Scripts/validate_density_pour.sh \
  build/round-vials/DerivedData/Build/Products/Release/VialsFluidLab.app/Contents/Resources/default.metallib \
  build/density-pour/trajectories --routes
```
