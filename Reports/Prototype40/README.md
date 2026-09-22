# Prototype 40 — machine connection guidance

The pre-existing Recovery, Discovery, concurrent-pour and role-shape checkpoint was committed and pushed as `761328d37c390156812d33a3de51c6a9bf148437` before starting this work. The remote branch was verified against that hash.

## Behavior

Opening a machine's information (or pressing its action while it is not ready) highlights the associated vessels. Inputs have dashed lavender outlines; outputs have solid outlines and arrowheads. Curved connections sit below the vessels. The guide names the exact input/output letters, and the corresponding footer cards and role badges highlight together.

The same connection appears when Hint recommends a machine and while that machine operates. A shared separator-output/mixer-input vial highlights the badge belonging to the focused machine. Density tools highlight only their chamber. The guide includes Show connections: closing it leaves the route visible for four seconds, avoiding a popover covering an important port. Selecting another vial, changing a machine hint or starting an operation clears that preview; an active operation retains its own route until completion. Changing levels clears the inspected machine. Ordinary pour selection and source/destination cues retain their existing behavior.

**Vial-to-vial pours are unchanged:** lifting, tilting, flowing and returning home remain in place. This work does not change physics, vessel geometry, capacity scaling, camera, machine transformations or puzzle rules. The connection overlay cannot intercept taps. Reduced Motion disables its fade.

## Validation

Mac interaction checks exercised Second chance in 3D/Classic/2D: information opening/dismissal, shared-role membership, separator hints, direct separator activation, mixer activation from its ready guide, completion and cleared cues. Accessibility exposes the active machine's port roles and the guide's exact route.

The Mac screenshot service returns tiny window previews, so those checks establish interaction/AX behavior rather than a full-resolution visual review. Device Hub input continues to time out; QuickTime remains the working iPad preview. A diagnostic `--inspect-machine <id>` option is restricted to isolated `--lab-trial --visual-review` launches for physical-device visual checks without touch forwarding.

Caffeinate is used during Mac UI checks. The scheduled performance monitor remains paused. New guidance changes are separate from the pushed checkpoint.

Physical-iPad inspection initially exposed the popover covering the shared port; the Show connections/brief post-dismissal preview addresses that. QuickTime’s View → Float on Top restored a full-size live screenshot when ordinary window captures were tiny. No movie recording was started.


## Final checks

- Final Mac Release and signed iOS Release builds passed; `git diff --check` passed.
- iPad installed with the final build. QuickTime landscape review inspected Recovery mixer connections in 3D, Recovery separator connections in 2D, and ten-vial Crossover mixer guidance in Classic. The final 3D guide visibly includes Show connections. Device Hub touch forwarding remained unavailable; no physical portrait review was performed in this pass.
- Final Mac Show connections action dismissed the guide while retaining input/output accessibility cues; a subsequent observation confirmed their expiry. Previous direct action and guide activation checks passed. A normal 3D B→A pour after separation committed successfully, with no machine connection cues attached to the pour.
- Geometry/rendering/physics files are unchanged from pushed checkpoint 761328d; changes are confined to the board UI, a decorative SwiftUI overlay, and documentation. No physics regression suite was repeated for this UI-only change.
- iPad returned to normal play after isolated inspection. No QuickTime recording was made. New guidance work remains local/unpushed, after the requested checkpoint push.

Density-tool wording correction: Make heavier/lighter now uses **Show chamber** with a scope icon and a chamber-specific accessibility hint. **Show connections** remains for mixers and separators. The same four-second preview behavior is retained.
