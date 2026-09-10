# Color-matched completion caps

Fully sorted, full vials now receive a shaded, color-matched stopper in Classic, 2D Fluid and 3D Fluid. The cap has a lit top, a rim and fine grip grooves. It fits the actual mouth width: area-scaled profiles in 2D, the Classic profile in Classic, and the board camera projection in 3D.

Completion no longer produces an outer teal outline, a Complete badge beneath the vial, a teal control-card border, or a cyan glass foot in 2D. Source, destination, rejection and hint cues retain their existing appearance. The checkmark on a completed vial's control card and its accessibility completion value remain available.

Caps appear only after a move commits, and disappear when Undo makes a vial incomplete. Selecting a completed vial uncaps it; its cap remains hidden while it is the moving source. Deselecting restores the cap if it is still complete. This is a visual change and does not lock vials or change legal moves. Empty, partially filled and mixed-color vials are not capped.

The caps use a static Canvas overlay with no particle-frame subscription, timer or new fluid simulation work. No gameplay, pacing, saved-data or sound changes were made.

## Verification

- macOS Release and signed iOS Release builds passed.
- Isolated Mac app `devplaceholder.A4UPBIXV.VialsCapChecks`, seeded with a disposable six-vial board containing completed blue/orange vials and green split 3+1.
- Live UI automation under `caffeinate -di`: checked all three presentations, selected/deselected a completed vial, completed a real 2D pour, undid it, switched back to 3D, completed a real 3D pour, and resized to a narrow window.
- Blue/orange caps remained distinct from teal pour hints; green gained a cap on completion and lost it on Undo. Returned 3D and narrow-window caps stayed aligned with their vial mouths.
- These are functional and visual checks, not new iPad performance measurements. The signed iPad build is ready; installation is held until Eddie confirms the device is free from tester use.

[3D](3d.png) · [2D](2d.png) · [Classic](classic.png) · [Source selected](selected.png) · [Completed 2D pour](solved-2d.png) · [Undo](undo.png) · [Return to 3D](3d-return.png) · [Narrow 3D view](3d-portrait.png)
