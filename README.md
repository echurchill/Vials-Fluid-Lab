# Vials Fluid Lab

[100-level Sorting Course and assistance history](Reports/Prototype52/README.md) doubles the stable curriculum while preserving Discovery every fifth level, records hint/helper use as neutral completion facts, and gives Valve Lab progressive lid guidance. All new boards are frozen from offline candidates and solved under the shipping Lab rules.

[Lab-native helper vessels](Reports/Prototype49/README.md) add two optional, fully Undoable and saved workspaces to Sorting: a one-unit tea cup, two-unit mug and three-unit jug. Helpers share the Lab's pour, hint, Discovery, concurrency and three-presentation systems, never count as completed targets, and must be empty to win.

[Valve Course consolidation](Reports/Prototype45/README.md) brings all fifteen Original receive-only experiments into the shared Lab engine with course navigation, progress, teaching, saves and full Lab-rule solver validation. It also records the recommended helper-cup and hybrid curriculum-expansion path.

[Round vessels and consistent fill heights](Reports/Prototype31/README.md) replace the rejected flattened-vial workaround. Mac comparisons and checks are available for visual review.

[Matched 3D board scale and a quieter floor](Reports/Prototype27/README.md) bring resting 3D vials into visual parity with Classic/2D across portrait, landscape and 4–10-vial boards, align the common floor baseline, and remove the unnecessary 3D floor ellipse while retaining contact shadows. Its latest follow-up also carries Classic streams down to the accumulating fluid and preserves visible 3D headspace beneath completed caps. Full complexity, concurrency and overlap regressions pass.

[Physical fill verification and expanded-level profiling](Reports/Prototype26/README.md) remove the remaining one-frame correction jump, confirm the Level 16 shared receiver and completion cap on the M4 iPad, revalidate depth-ordered caps, and measure the 10-vial Sixfold workload on device.

[Variable-capacity and receive-only Lab boards](Reports/Prototype25/README.md) extend the shared progression to 16 levels, with visibly height-scaled 3–6-unit vessels, up to 10 vials and 6 colors, two fill-only valves, stable multi-step hints on the live concurrent-capable board, dependency-constrained pours beyond two simultaneous sources, and canonical final settling that prevents detached 3D particle clusters. Complete Classic/2D/3D regressions and physical-iPad layout checks pass.

[Unequal-capacity solver pruning](Reports/Prototype24/README.md) fixes a false dead end in the bundled Original game and adds generated-level, receive-only, helper and four-move counterexample coverage.

[Depth-ordered completion caps](Reports/Prototype23/README.md) keep a rear completed stopper behind crossing vials in Classic, 2D and 3D. Mac regressions and signed iPad portrait/landscape checks pass.

[Reset all progress](Reports/Prototype22/README.md) adds a confirmed fresh start from the Board options menu, clearing all saved levels and bundled Original game progress. Mac UI and state checks pass.

[Smoother 3D glass edges](Reports/Prototype21/README.md) add antialiasing to the stronger outlines. Mac visual/overlap checks pass; the signed iPad build is ready for device validation.

[Stronger 3D glass edges and USB profiles](Reports/Prototype20/README.md) improve vial visibility and record actual iPad frame timing. The updated app is installed on the iPad.

[Cached pour setup and separated 3D travel](Reports/Prototype19/README.md) reduce repeated preparation work, separate crossing paths and keep edge pours in frame. Its completed-cap overlap follow-up was resolved by [Prototype23](Reports/Prototype23/README.md).

[Shared receivers and clearer overlapping vials](Reports/Prototype18/README.md) add simultaneous streams into one receiver and fix stale particle inventory during rapid consecutive pours.

[Pause-aware motion and concurrent pours](Reports/Prototype17/README.md) add two overlapping pours in all three views, capacity reservations, and device measurements.

[Stable idle detail and the latest iPad check](Reports/Prototype16/README.md) address the extra lines at pour boundaries and record the latest device trial.

[Translucent 2D materials and responsive pickup](Reports/Prototype15/README.md) add restrained idle detail, touch-down feedback and a more visible start to the lift.

[Color-matched completion caps](Reports/Prototype14/README.md) distinguish fully sorted vials from source and destination hints in all three presentations.

The latest [highlight and 3D surface fixes](Reports/Prototype13/README.md) strengthen selection cues and handle presentation switching safely.

The latest [2D redraw optimization and display-gap investigation](Reports/Prototype12/README.md) includes measured iPad CPU results and a [checklist for tonight’s testing](Reports/Prototype12/TestingTonight.md).

Independent native Swift + Metal investigation of liquid pouring. Prototype 06 adds a true **2D Fluid** particle experiment alongside **Classic / 3D Fluid**. All three presentations share the 16-puzzle progression, per-vial capacities and rules, progress, hints, undo and **Relaxed / Quick** pacing. The 2D mode uses equal-area particles, shape-dependent fill heights and smooth flat liquid silhouettes. The 3D mode retains its equal-volume simulation. The teal pouring-vial icon distinguishes this Lab from the original game.

Start with **Green arrival → 2D Fluid → Quick**, then switch presentations between moves. Use **Board options → Compare last pour** to replay a completed transfer across all three views at a matched duration. Board diagnostics can reveal the particles. Sound is unchanged. Fluid detail controls apply to 3D; the 2D Canvas currently draws at native view resolution.

See the latest [finished-build profiling](Reports/Prototype11/README.md), [glass, interaction feedback and matched comparisons](Reports/Prototype10/README.md), [surface/material polish and iPad checks](Reports/Prototype09/README.md), [real-time 2D execution and measured comparisons](Reports/Prototype08/README.md), [2D materials and faster pours](Reports/Prototype07/README.md), [2D experiment notes, validation and captures](Reports/Prototype06/README.md), or the [previous 3D progression and battery results](Reports/Prototype05/README.md).

Open `Vials Fluid Lab.xcodeproj` and select the shared **Vials Fluid Lab** scheme. Run now uses **Release** for performance testing. Use **Vials Fluid Lab Debug** when you need an unoptimized debugging build.
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
