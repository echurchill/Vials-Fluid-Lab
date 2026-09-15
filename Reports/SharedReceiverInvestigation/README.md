# Two sources pouring into one receiver

Investigation of commit `cbc408c`, September 15, 2026. No gameplay or renderer code was changed. No iPad trial or live Mac UI automation was performed for this investigation. The probes compile and exercise existing model/geometry code; they do not simulate a working shared-receiver pour.

**Recommendation:** support two genuinely overlapping streams by giving each receiving vial one simulation containing both sources and the receiver. Keep separate motion clocks and fixed volume reservations for each source. Retain the two-active-pour limit for the first implementation. Swift/Metal can support this architecture; the blockers are in our current single-transfer assumptions.

## Confirmed blockers

1. **Dispatch deliberately locks the receiver.** `LabPourQueue.startReady` treats every source and destination as exclusive. Reservations already accept two compatible incoming moves, but only one starts. Changing this condition alone is insufficient.
2. **The model re-derives the maximum amount at start and completion.** `LabBoardState.applying` requires equality with a newly computed maximal move. With two three-unit sources and an empty four-unit receiver, the queue correctly reserves 3 + 1. The one-unit transfer cannot start against the unchanged committed board or finish first: that board still permits three units. The standalone probe found this issue in 14 of 24 small capacity fixtures that accept both moves. The 2 + 2 case happens to succeed in either order and would miss this defect.
3. **Two engines cannot own separate copies of the same receiver.** `LabConcurrent2DWorker` and the 3D lane controller currently solve independent pairs and merge their parcel sets. A nonempty common receiver would belong to both sets; one result would overwrite the other. Starting from empty avoids that initial overlap but still gives each solver an incomplete receiver inventory, fill level and interaction state. Staggered joins make this worse.
4. **Existing same-side approaches coincide.** Source direction is chosen from home position. The geometry probe places sources A and B over receiver C at time 2, tilt 1.2: both 3D world transforms are exactly equal. Classic uses the same destination/side-dependent approach pattern; 2D also needs explicit approach positions. Moving sources apart only at their original homes does not solve this.
5. **Finishing one pour currently resets shared state.** 2D cleanup interpolates a complete particle snapshot, zeroes velocities and clears receiver surface effects. 3D cleanup verifies the complete inventory and can reassign same-colored parcel IDs by height. Those operations would disturb or invalidate a second active transfer. Rollback also restores a whole snapshot today.

[Probe output](findings.txt), [reservation probe](probe.swift), [geometry probe](geometry.swift).

The original game confirms the requested behavior: `ContentView.canSchedulePour` permits a receiver already receiving, while preventing outgoing use of any involved vial. It commits logical volume on acceptance and sums incoming visual adjustments. Fluid Lab currently commits at completion so it can validate physical capture. Preserve that behavior rather than silently changing save/Undo semantics to match the original implementation.

## Proposed implementation

### Reservations and completion

Add an explicit operation for applying an accepted reservation. Validate the reserved source parcel IDs, same-color top run, exact amount, receiver color and capacity. Do not recompute a larger amount merely because another reserved pour has not committed yet. Keep ordinary move generation maximal. Apply the same exact-reservation semantics when projecting outstanding moves.

Allow active moves to share a destination but never a source; a receiver must remain stationary and unavailable as an outgoing source. Maintain the existing two-pour global limit. Accept a third compatible reservation into the queue. Completed moves enter history once in completion order. A failed earlier transfer must not enlarge a later accepted transfer. Saved checkpoints still include completed moves only.

### Motion

Assign two stable approach positions around each receiver: opposing sides in Classic/2D, separated horizontal angles in 3D. The first pour gets the preferred available position. A later source uses the other without shifting the first source or its stream. A source that starts on the same side may need an elevated crossing path to reach the far position.

Keep the assigned position until that source has cleared the receiver on its return. Test the full silhouettes against each other and neighboring vials, especially broad flasks, portrait layouts and late joins. Approach travel may briefly wait for clearance, but normal paired fixtures must show both streams flowing together. Do not merely overlap the lift/return animations while serializing fluid transfer.

### Shared fluid ownership

Group work by receiver. A group owns one particle state and one fixed-step solver, plus independent records for each source's lift, tilt, cutoff, return, selected parcel IDs and capture counts. A second source joins the existing state without reseeding or relaxing the receiver. Advance the receiver and its surface response once per step, using arrivals from both streams. Combine group results for display only once per owned vial/parcel.

For 2D, replace the single `game.pending`, motion time and cutoff assumptions in pose, constraints, impact effects and cleanup with per-transfer records. Calculate bulk volume from the actual combined particles. Preserve the actor, bounded batches and rollback of a batch overtaken by pause.

For 3D, one group can mark two eligible moving sources and one receiver in the existing vessel-role/active-mask structure. The host needs per-transfer metrics, bands, motion and cleanup. The existing funnel is naturally aimed at the group's one receiver. A single global board solver would additionally need explicit destination routing; grouping by receiver keeps that unnecessary for this step. This shader compatibility is a code-review finding, not a measured prototype result.

Track capture and the allowed 5% correction separately for each transfer. Finishing one source must not snap, freeze, reseed or relabel the other's liquid. Defer receiver-wide ordering/normalization until no transfer still relies on those IDs. Restore only a failed transfer's parcels when safe; if the shared solver becomes invalid, rebuild unfinished work from the latest committed state without discarding completed moves. Keep the receiver uncapped until its incoming work finishes.

Classic already sums the contributions of `additionalPours` into one receiver. It chiefly needs the model, scheduling and motion changes, making it a useful first visual check of the shared design.

## Order of work and acceptance checks

1. Implement exact reservations and independent completion, then the two approach positions in Classic. Cover 2 + 2, 3 + 1, prefilled receivers, reverse completion, a failed first transfer, incompatible colors and a queued third source.
2. Implement one shared 2D receiver simulation. Test simultaneous starts and a second source joining during tilt, flow, cutoff and return. Check that volume and settled liquid do not jump when either pour starts or finishes. Verify each stream actually overlaps in arranged fixtures and each transfer stays within 5% cleanup.
3. Port the same group lifecycle to 3D. Test narrow mouths, broad source bodies, both source-home directions and camera/viewport changes. Repeat pause/background, reset, partial save, Undo and solved-state checks in all views.
4. Run isolated iPad trials comparing equivalent independent and shared-receiver workloads. Record per-transfer completion/corrections, controller intervals, displayed-frame timing, CPU/GPU work and thermal state separately. Keep USB profiling distinct from unplugged battery observations. Preserve normal saved progress and use `caffeinate -di` during Mac UI automation.

## Performance expectation and limits

Two sources plus one receiver means three active vials rather than four in two independent pairs. Sharing the receiver avoids duplicate work and leaves the total particle inventory unchanged. That is a promising design inference, not a speed guarantee: the merged liquid body can increase neighbor-search work, and the receiver receives two streams of impacts. Allocation and snapshot costs also need profiling.

The available 2D iPad reference is Prototype17: 49 successful pours in 120.021 seconds, two independent pours active, worker p95 5.090 ms, controller interval p95 17.918 ms and nominal thermal state. These are not compositor FPS measurements. Concurrent 3D iPad performance remains unmeasured. No defensible shared-receiver speed estimate is available until the prototype runs.

This is a moderate change to the model and Classic motion, and a larger refactor of the 2D/3D transfer lifecycle. The recommended first implementation is the reservation/Classic/2D slice, followed by 3D on the same tested group model.
