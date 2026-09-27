# Prototype 58 — visible 3D valve-lid motion

## Outcome

Color-keyed valve lids now visibly hinge open during incoming 3D pours, matching Classic and 2D Fluid.

Concurrent 3D pours are simulated in a small renderer dedicated to each receiver, then composited into the visible full-board renderer. Vessel transforms and particles were already copied into that visible renderer, but the valve-lid opening fraction was not. The hidden receiver simulation therefore opened its lid while the on-screen copy remained closed.

The receiver renderers now publish their current lid-opening fractions with the rest of the composite frame. The visible renderer uses that value for the same hinged cap transform and clears it whenever motion is reset. This is presentation-only state; valve rules, reservations, fluid motion, saves and completion are unchanged.

## Validation

- macOS Debug build passed.
- A new unsolved keyed-valve fixture performs a concurrent matching-color 3D pour and requires the visible composite lid to open beyond 90 percent.
- The regression captures the open lid during the pour; inspection confirms it is hinged clear of the vial mouth.
- Static empty keyed lids still render in Classic, 2D Fluid and 3D Fluid.
- Existing Course 45 seven-move and large-source 3D pours pass.
- All 18 cross-lab/presentation concurrency cases plus density, Discovery and machine-exclusivity checks pass.
- A signed physical-iPad Debug build passed and was installed with existing app data preserved. The automated launch was declined because the iPad had relocked; opening the installed app manually is the remaining device interaction check.
