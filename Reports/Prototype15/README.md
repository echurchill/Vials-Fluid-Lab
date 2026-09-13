# Translucent 2D fluid and more responsive pickup

Tester feedback favored the 3D appearance, found all three modes readable, and generally liked the pour pace. This update focuses on 2D material appearance and immediate interaction feedback. Concurrent pours remain a separate controller/simulation project.

## Appearance

The reconstructed 2D liquid is less opaque: blue 0.44, green 0.70 and orange 0.78, with soft cross-vial shading. Blue particle cores are less frequent and less bright; green ribbons and orange bubble outlines are softer. Color boundaries, particle locations and capacity are unchanged by these material effects.

A separate small Canvas draws drifting internal highlights, a few specks/bubbles and a faint ripple just below the surface. It runs at at most 12 updates per second while the board is idle and active. It does not advance the solver or subscribe the board controls to an animation clock. Pause, sheets/backgrounding, Reduce Motion, low-power mode and non-nominal thermal conditions pause the idle timeline; particle-debug mode hides it. The ripple stays within the liquid and does not alter its fill silhouette.

[First native preview](idle-a.png) and [eight seconds later](idle-b.png) show the restrained material motion. These are offscreen SwiftUI renders of the actual view, not mockups.

## Response

Vial hit targets and their lower control cards acknowledge touch-down with a subtle lit outline/background, before the action fires on release. The initial lift curve starts with visible movement instead of a nearly stationary ease-in. The lift duration, travel, pouring and return durations and pace settings are unchanged. The 3D solver's short preparation interval remains in place.

The lift curve retains the same endpoints and comes to rest at the top. At 1/30 of the lift interval it reaches about 2.35% of its height, compared with 0.33% previously. This improves the visible pickup response; it is not a measured end-to-end input-latency result and does not remove the one-pour-at-a-time rule.

## Validation and delivery

- macOS Release and signed iOS Release builds passed.
- Existing comparison suite: all nine matched Classic/2D/3D replays committed; one-, two- and three-unit examples, matched durations, normal pace, pause/stop and save isolation passed.
- Session checks passed commit, pause, suspension, reset, reload, mode switching, Undo, no-Metal fallback, worker cancellation and immutable snapshots.
- Publication check recorded 203 liquid updates and seven board/control updates during the checked pour.
- Two native offscreen material previews were inspected, eight seconds apart.
- Live touch-down/idle-pause UI checks remain pending: the Mac reported a locked session, and the isolated app's accessibility window was unavailable. `caffeinate -di` was active during testing; it prevents idle sleep but does not unlock the Mac.
- Per Eddie's instruction, leave the iPad unchanged and continue testing on the Mac. No new iPad performance or battery measurements are claimed. The performance monitor was resumed because code changes have restarted.

[Comparison results](comparison.json) · [Comparison checks](comparison.log) · [Session checks](session.log) · [Publication counts](publication-counts.json)
