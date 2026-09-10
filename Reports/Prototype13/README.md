# Clearer hints and safe 3D surface replacement

All three Fluid Lab presentations now use the same outer hint border: a solid three-point source outline and a 2.5-point dashed destination outline, with higher opacity and a dark under-stroke for contrast. The 2D outline is no longer hidden in favor of its thin glass-edge tint. Existing source/destination labels remain in place. The independent liquid-frame publisher is unchanged, so this does not restore per-frame board/control updates.

The 3D idle-render cache previously recorded a desired drawable size before acquiring a drawable. An unavailable drawable could therefore suppress the retry. The cache also did not identify which Metal view had received the frame. These are unsafe when SwiftUI replaces the Metal view during presentation switching.

The renderer now:

- waits for nonzero layout bounds;
- sizes the drawable for the current bounds and quality;
- rejects stale-sized drawable textures during resize;
- caches idle state only after submitting a frame, and only for that view;
- invalidates the idle cache on drawable-size changes.

The new surface no longer starts with a hardcoded 1000×650 drawable. The camera still uses the actual render-target aspect ratio, and the hint geometry uses the displayed board bounds. The solver, rules, saved-game format and pour timing are unchanged.

## Validation

The real-MTKView regression passes missing-drawable retry, idle redraw suppression, same-size replacement views, stale-size retry, portrait resize and preservation of fluid positions. Running this same test against the prior renderer fails at **“Missing drawable incorrectly cached as a rendered idle frame.”** The baseline failure is intentional verification of the regression test, not a crash of the delivered game.

Run with a built macOS shader library:

```
bash Scripts/validate_surface_lifecycle.sh /absolute/path/to/default.metallib build/surface-check
```

The existing glass/comparison suite passes all nine matched one-, two- and three-unit replays, control/busy guards, preview isolation, pause/suspension/reset/undo/save/reload, and particle snapshot checks. The separate publication check still records 200 liquid frames and seven board updates for its complete pour. Signed iOS and macOS Release builds pass.

Live Mac UI automation verified Deep current with source A selected through the complete 3D → 2D → Classic → 3D sequence. The outer source and destination outlines remain clear in every presentation, and the returned 3D vials remain aligned with their outlines. The screenshots below record each stage. The corrected signed iPad app was installed and launched with existing app data retained; the on-screen sequence was checked on the Mac.

Keep `caffeinate -di` running throughout Mac UI automation so both display sleep and idle system sleep remain inhibited. Release it when the test run finishes. This visual check used a timed `caffeinate -di -t 1800` assertion.

[Initial 3D](3d-selected.png), [2D](2d-selected.png), [Classic](classic-selected.png), [returned 3D](3d-returned.png).

[Surface regression](surface.log), [expected failure with the prior renderer](surface-before.log), [comparison checks](comparison.log), [controller checks](session.log).
