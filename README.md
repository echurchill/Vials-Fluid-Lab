# Vials Fluid Lab

Independent investigation copy of Vials. No fluid simulation has been implemented yet.

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
This copy has its own Git repository and baseline commit, with no remote configured.
No original Git history, Xcode user state, or build output was copied.

## Baseline verification

The shared scheme passed an unsigned Debug build for macOS with Xcode 27.0 (27A5237l).
The built app bundle confirms the separate identifier and display name.
Device signing, installation, and interactive gameplay have not been tested for this copy.
All copied game source, scripts, and assets match the source snapshot.
