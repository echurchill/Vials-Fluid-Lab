# Prototype 60 — Instruments Lab

The first Instruments Lab vertical slice introduces a pipette that moves exactly one exposed unit from a fixed input to a fixed output. It preserves the parcel’s pigment, density and volume, rejects empty inputs, full outputs and mismatched output material, and participates in hints, Undo, saves, first-use teaching and accessibility.

Four authored levels establish the mechanic:

1. **Precise drop** — measure one unit.
2. **Repeat measure** — use the same instrument twice.
3. **Uncover the sample** — expose a buried material before sampling it.
4. **Measured reaction** — feed two measured units into the existing mixer.

The instrument uses the previously reserved pear-flask silhouette and `PIP IN` / `PIP OUT` role badges. Classic draws a one-unit transfer stream, while 2D and 3D move only the sampled parcel to its canonical destination. The transition has no mixer recoloring or agitation.

Two small consolidation changes ship with the lab:

- **Original game (legacy)** is removed from the normal board menu. Developers can restore it with `--show-legacy-original` while the old implementation remains available for reference.
- The compact iPhone helper card omits the redundant `HELPERS` heading and shortens `ADD TEA CUP` to `ADD`, retaining its icon, count, two slots and full accessibility description.

## Validation

- macOS Debug build
- iOS Simulator Debug build
- signed generic iOS Debug build
- all 47 authored Lab model routes
- all 26 target/apparatus session routes, animated Pipette checks and five-lab persistence
- all 21 discipline/presentation concurrency cases plus density, Discovery and machine regressions
- Journey, Endless Sorting, reset-progress and full complexity regressions
- cross-mode vessel presentation and animated Pipette rendering checks
- live Mac Precise drop activation and completion
- iPhone 17 Pro Max Simulator launch and screenshots for the compact helper card and Instruments Lab in 3D

The Instruments Lab is directly selectable but is not yet part of Journey. That keeps this first four-level experiment easy to revise before it affects the guided campaign.
