# Density triangle prototype

September 20, 2026. Density readability and animation checkpoint, built on `083d383`. Includes the apparatus animation documented in Prototype34. The physical-device addendum below supersedes earlier device-status notes.

## Visual treatment

Hue now identifies pigment at every density. Light fluid has pale upward triangles with a pigment outline; medium has no density motif; heavy has filled downward triangles in a dark shade of the pigment. Small deterministic size variation and staggered placement keep the symbols consistent without being identical. Information-card symbols are described below; spoken density names remain.

Classic centers motif rows within each layer, including thin layers, and clips them to the liquid. 2D masks the same motifs to the reconstructed particle surface and follows the vial pose. Decorative ribbons are suppressed in density puzzles to avoid competing directional shapes. Blue transparency and other pigment-specific effects no longer depend on the density bank.

3D evaluates antialiased triangles on the reconstructed fluid surface in vial-local coordinates. A two-channel density-weight texture is written alongside existing depth/color outputs, with no additional render pass. The weights crossfade during apparatus changes. Nearest front-surface density determines the symbol, rather than mixing markers from fluid behind it. Airborne drops do not carry symbols. Surface texture gradients may make the 3D symbols softer than the planar versions.

The encoded visual dye still carries density metadata for layer identity and rendering. Puzzle rules, quantities, stored pigment/density values, density settlement and particle budgets are unchanged. Cap and information-card colors use the base pigment too. This prototype currently replaces the brightness encoding; it does not add a preference toggle.

## Review

Use Density → Shades of blue in the Mac app and switch Classic / 2D Fluid / 3D Fluid. Crossover → Equal partners demonstrates Make heavier removing the light symbols; a second activation adds heavy symbols. Undo restores the prior appearance.

The fixed fixtures below use actual renderers. Each layered vessel has heavy at the bottom, medium in the middle and light on top, all with the same pigment.

- [Classic](layers-classic.png)
- [2D Fluid](layers-fluid2D.png)
- [3D Fluid](layers-fluid.png)
- [Small one-unit vessels](small-fluid.png): light, medium, heavy blue, followed by light, medium, heavy orange.
- [Ten-vial board](wide-fluid.png)
- [Portrait](portrait-fluid.png)

## Validation and limits

- Mac Release and signed generic iOS Release builds passed.
- Twelve fixed renders cover six pigments, stacked same-color density layers, one-unit vessels, ten-vial boards and portrait layouts. Representative images were inspected; final 2D images include the reduced decorative ribbons.
- All 18 animated density cases passed with particle containment, pause/suspension, cancellation, undo, final continuity and subsequent pours.
- All 48 animated mixing cases passed with the new Metal outputs and shared pigment rendering.
- Seven density-pour trajectory fixtures passed in both particle renderers, with Classic intermediate captures. Stable density ties, volume, pause and completion checks passed.
- The updated Mac app was launched. Actual UI activation in Equal partners paused/resumed and committed Light Ruby → Medium Ruby (one additional move), then Undo restored Light Ruby. The 2D activation and pause were exercised. Later screen-capture errors and interrupted UI actions prevented finishing the remaining UI sequence or leaving the app on Shades of blue. caffeinate ran during the UI checks.
- No physical iPad install, device profiling, battery measurements, or tester accessibility acceptance yet. The added render attachment has not been profiled on device.

Run `bash Scripts/preview_density_patterns.sh <built macOS default.metallib>` for the fixed fixtures. Existing density-change, mixing and density-pour scripts produced the included logs.

## Contents and target strips

Eddie found the tiny L/M/H letters hard to read. Both rows now use the same shared LabDensitySwatch: pale upward triangle for Light, plain for Medium, dark downward triangle for Heavy. Density strips are 14 points tall (formerly 7), with a 9-point symbol and insets that fit compact widths. The target uses the same full pigment color as actual contents plus its outline and TARGET label. Spoken material/target descriptions remain on the parent vial button.

Mac and signed iOS builds passed. The actual component was rendered at normal and compact widths and inspected (card-density-symbols.png). The updated Mac app was relaunched at Eddie's Equal partners board; its screenshot clearly shows two downward triangles for G's Heavy Ember contents above two plain Medium Ember target segments. This is shared UI for all three presentations. No physical iPad validation yet.

## Directional fade during density changes

Incoming light triangles now fade in while drifting upward; heavy triangles fade in while drifting downward. Outgoing triangles continue in their pointing direction while fading away. The short 0.18-scene-unit drift eases to the normal stationary pattern positions. Only the apparatus output is affected, across Classic, 2D and 3D. The shared transformation clock freezes both fade and drift during pause/suspension; Reduced Motion retains the fade with zero drift. No render pass was added.

Mac and signed generic iOS Release builds passed. All 18 density-animation cases passed, including direction, final alignment, Reduced Motion, pause/suspension and existing inventory/lifecycle checks (density-drift-validation.log). Intermediate Classic/2D light and 3D heavy fixture images were inspected. The updated Mac app completed 2D activation/pause/resume and 3D activation/pause/resume checks. caffeinate ran during UI automation. No physical iPad test yet.

## Physical iPad verification — September 20

Installed the current signed Release build on Eddie's connected 13-inch M4 iPad Pro (CoreDevice 708ACD1F-C8CB-558B-AC94-B6225F02FE7E). A new opt-in `--lab-trial --check-density-controls --keep-awake` replay uses the live app, its normal animation clock and all three presentations. It covers Light→Medium, Medium→Heavy, Medium→Light, and Reduced Motion Medium→Heavy in each view. The diagnostic is isolated from saved progress and absent from ordinary launches.

All 12 cases passed: activation, ignored double activation, frozen pattern offsets/time and particle positions during pause, resumed sampling, monotonic arrow-direction drift, Reduced Motion without drift, exact single commit, particle inventory, renderer error checks, Undo, and Reset cancellation. See [raw device results](ipad-density-controls.json). The iPad reported nominal thermal state. This is functional evidence, not touch automation, displayed-frame-rate, GPU-cost or battery evidence.

Both signed iOS and macOS Release builds including this diagnostic passed. caffeinate ran throughout Mac automation. Direct visual inspection on iPad remains pending: Device Hub and QuickTime automation repeatedly returned timeoutReached, including after Eddie confirmed the Mac was unlocked and the automation connection was reset. Xcode and the Mac game were accessible, but the iPad preview apps were not. The iPad app was relaunched normally after the checks, without trial flags.
