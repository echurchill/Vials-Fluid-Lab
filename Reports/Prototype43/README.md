# Returned sources remain locked after touchdown — September 22

## Reproduction and causes

Eddie reported Discovery → Buried clue, Quick: B→D, A→C, then B→C as soon as B returns. A lands but remains marked Pouring until B finishes. The new deterministic regression reproduced this in 3D before the fix. Eddie then reported 2D too; the expanded regression reproduced that independently.

- 3D committed a receiver group only after every source returned. A late incoming pour could also cancel the group's short settle and clear the older source's completed-settle flag.
- 2D waited until after the source's complete return plus a settle interval to begin cleanup. Thus its pose reached home before its interaction lock expired.
- Classic's rendered descent ends at 7.2 simulation seconds, but completion waited until 7.6.

## Changes

3D releases completed reservations in order without waiting for newer streams. A receiver already interpolating its final correction briefly defers a new start until that correction finishes. Already-settled sources retain that status. If another stream is still simulating, an eligible returned source can finish with the existing maximum-five-percent correction applied only to its missing transferred particles. Normalize the released source's parcel IDs for immediate reuse; preserve the active receiver's IDs until its remaining transfers commit.

2D performs its bounded correction during the return, then commits at touchdown. Corrected particles are released back into the live simulation after interpolation. Classic completes at its actual touchdown time.

No vial geometry, size, camera, lift/tilt/return path, material appearance or shader changes. Reservation order, Discovery reveal protection, and the five-percent correction limit remain in force.

## Validation

- `Scripts/validate_returned_source.sh`: 24 cases, three presentations × two paces × four initial timing offsets. The exact B→D / A→C / B→C sequence must allow returned A→D while B remains active. Checks the actual rendered pose in 2D/3D and Classic's descent endpoint, prevents a stale Pouring reservation, and verifies four commits, parcel ownership/counts, saved state and Undo.
- Existing `validate_lab_concurrency.sh`: all 18 lab/presentation cases plus mixed/equal density arrivals, overlapping Discovery reveals, pause/suspension, machine exclusion and reset cancellation pass.
- Final Mac and signed iOS Release builds pass. Only the existing AppIntents metadata-extraction warning remains. `git diff --check` passes.
- Live Mac UI automation with caffeinate: reproduced the four-action sequence in 2D and 3D / Quick. Accessibility shows A enabled while B remains Pouring; starting A→D changes the board back to two pours / two committed moves. The 2D run subsequently completed all four moves. These are actual UI interactions; screenshot thumbnails remain distorted, so this is not a full-resolution visual review.
- Physical M4 iPad, Quick Buried clue concurrent diagnostic smoke tests: 3D 14/14 pours committed, maximum cleanup 0.469%; final 2D build 18/18 committed, zero cleanup. Both reached two simultaneous incoming pours and completed/drained normally. These short trials are controller-driven checks, not a claim of touch reproduction, compositor FPS or battery performance. The exact return-and-reuse sequence was verified by Mac UI and deterministic tests.

The final signed build is installed on the iPad, relaunched without diagnostic flags. Mac runs the final build on Buried clue / 3D / Quick. Eddie confirmed the behavior was much better and requested this checkpoint be committed and pushed. The unrelated root PNG remains untouched; scheduled performance monitor remains paused. Testing-only caffeinate was stopped.
