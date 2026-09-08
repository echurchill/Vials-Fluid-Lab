# Vials Fluid Lab

Independent native Swift + Metal investigation of 3D liquid pouring. Prototype 03 opens a playable four-vial sorting board. **Other experiments** contains the earlier **Pour study** and the original **Classic game**.

See [prototype review notes, measured results, and captures](Reports/Prototype03/README.md).

Open `Vials Fluid Lab.xcodeproj` and select the shared **Vials Fluid Lab** scheme.
The target/product is `VialsFluidLab`; the installed display name is **Vials Fluid Lab**.
Its bundle identifier is `devplaceholder.A4UPBIXV.VialsFluidLab`, distinct from the original app, so app-local progress and settings remain separate.
The original project's development team and platform settings are retained. Device builds require normal Xcode signing for this new app identifier.

## Investigation scope

Use Swift and Metal; evaluate RealityKit where useful. **Do not use Unity.**
This decision supersedes the Unity comparisons in the copied historical reports.
Start with two 3D vessels, geometry-correct equal-volume filling, and a simulated lift/pour/return sequence.
Measure rendering quality and performance before migrating the full game.

## Copy provenance

- Source: `/Volumes/Code Work/xCode work/Vials`
- Source HEAD: `828abdb4b484efa21e7133dbe4a78ec91459ab04`
- Copied: 2026-09-07T23:08:14.121767+00:00
- Includes the latest committed work and the uncommitted fluid simulation plan.
- Source working-tree status at copy time:

```text
?? Reports/3d-fluid-simulation-plan.md
```

`Reports/source-copy-manifest.json` records SHA-256 hashes of copied files before lab-specific project metadata changes.
Source and asset directory names remain `Vials` to keep game code unchanged.
This copy has its own Git history, originating at baseline commit `633d988`. Its GitHub repository is `echurchill/Vials-Fluid-Lab`, on branch `codex/fluid-lab`.
No original Git history, Xcode user state, or build output was copied.

## Original baseline verification

The shared scheme passed an unsigned Debug build for macOS with Xcode 27.0 (27A5237l).
The built app bundle confirms the separate identifier and display name.
This describes the original copy baseline; current prototype checks are recorded below.
All copied game source, scripts, and assets match the source snapshot.

## Prototype verification

Prototype 03 passes unsigned macOS and iOS builds and 18 offscreen transfers covering full solutions, variable amounts, destination capacity, different shapes, colored layers, exact undo, pause, and reset. The worst measured board cleanup was 0.313% of the intended transfer. Run `bash Scripts/validate_fluid_board.sh` to reproduce the checks.

The retained Prototype 02 pour study passes its shared-shader regression fixture; `bash Scripts/validate_fluid_lab.sh` runs its full suite. Physical iPad testing remains pending. See [Prototype 03 notes](Reports/Prototype03/README.md) for measurements, captures, and visual/physics limitations.
