# Visible density apparatus changes

September 20, 2026. The mixing/shadow checkpoint was committed and pushed as `083d383b49d277732540ef9137e0153d07adecb6`; GitHub branch `codex/fluid-lab` was verified at that exact commit. This subsequent density animation is local and uncommitted.

## Behavior

Make heavier and Make lighter now animate in Classic, 2D and 3D. The density tint blends gradually while a gentle internal motion goes down through the center for heavier liquid and up for lighter liquid. Classic uses directional curved streaks; particle views move their existing samples inside the chamber. At completion all samples return to their original positions with the new material appearance, avoiding repacking or a fill-height jump. The 2.2-simulation-second transition follows the selected pace.

The apparatus currently accepts only a uniform material and changes the entire chamber. There is no separate resident layer to cross during this operation. Quantity, pigment, fill level, activation eligibility and puzzle rules are unchanged. Subsequent pours use the existing density-aware settlement.

Mixing and density changes share LabApparatusTransition and one session clock. Logical state commits once after animation. Pause/background suspension freezes elapsed time; Reduced Motion leaves density particles still while color changes; Undo restores the previous density; Reset cancels the transition. Saved checkpoints during animation contain the last committed board.

## Validation

- Release macOS and signed generic iOS builds pass, with only the standard no-AppIntents metadata note.
- All 18 authored density-modifier fixtures pass across three views. These check single deferred commit, duplicate activation, unchanged inventory/pigment, finite particles, retained owners, glass containment, unaffected neighboring particles, pause/suspension, pre-transition save, reduced motion, final continuity, following pours, undo and reset. See density-validation.log.
- All 48 mixer fixtures still pass, including their post-mix pours, via the updated shared transition API. See mixing-regression.log.
- Offscreen renders at multiple stages were inspected in Classic/2D/3D, including heavier orange and lighter green. Representative images are included here.
- Mac UI automation launched the new build, opened Equal partners and started A-to-C to fill the chamber. The remaining activation/pause/undo button check could not finish: CUA twice returned ScreenCaptureKit error -3811 (audio/video capture failure). caffeinate was running throughout. Do not claim a completed live UI test for this density change.
- No physical iPad install, device performance profile, or battery test was attempted.

Run `bash Scripts/validate_density_change.sh <built macOS default.metallib>` and `bash Scripts/validate_mixing.sh <built macOS default.metallib>`.

## Proposed follow-up, not implemented

Eddie suggested separating pigment from density using pale upward triangles for light liquid and dark filled downward triangles for heavy liquid, with modest size variation. Medium could remain plain. Prototype contrast and symbol density in thin layers and small vials across Classic/2D/3D before replacing brightness encoding. This was a request for thoughts, not authorization to implement the pattern change. Existing density tint remains for now.
