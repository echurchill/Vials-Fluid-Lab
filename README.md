# Vials Fluid Lab

Independent native Swift + Metal investigation of 3D liquid pouring. Prototype 05 has a 12-puzzle progression with four- and six-vial boards, up to three colors, switchable **Classic / Fluid** presentation and **Relaxed / Quick** pacing. Both styles share progress, hints and undo. Board options include optional pouring sound, haptics on supported hardware and render-detail choices. The teal pouring-vial icon distinguishes this Lab from the original game. **Board options** also contains the earlier **Pour study** and the **Original game**.

See [prototype review notes, measured results, and captures](Reports/Prototype05/README.md).

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

Prototype 05 passes macOS and signed iOS builds, 162 progression/comparison transfers, and the retained pour-study regression. All 12 authored levels have verified legal solutions. New-level Quick Fluid turns take 3.92–5.27 seconds in the fixtures, with at most 0.625% cleanup. Run `bash Scripts/validate_progression.sh` to reproduce the main suite.

Ten-minute unplugged iPad trials compare Classic and Fluid on the same six-vial puzzle. Read the [measurements and their limits](Reports/Prototype05/Measurements.md), [prototype notes](Reports/Prototype05/README.md), and [tester instructions](Reports/Prototype05/Testing.md). Historical results and the icon generation prompt remain in Reports/Prototype04.
