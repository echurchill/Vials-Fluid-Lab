# Color-keyed valve lids — September 24

## Player experience

- The provisional cyan line, arrow and floating `FILL` badge are gone. Every receive-only valve now has a physical lid whose color declares the only pigment it accepts.
- A matching pour hinges the lid open in Classic, 2D Fluid and 3D Fluid, then closes it after the transfer. A wrong-color attempt never begins and explains which pigment the lid accepts.
- Each lid also carries one of four high-contrast motifs. The vial's accessibility description names the keyed pigment and explains that the valve cannot pour out, so hue is never the only rule cue.
- Valve Basics 1 is now the empty-valve teaching board. Its Tide unit moved into an ordinary vial, preserving the original pigment inventory while letting the lid teach the target color before any liquid enters.

## Shared model

- `LabBoardState` stores one optional pigment key per vial. Keys are encoded in saves, included in solver/canonical keys, retained through Undo and projected reservations, and validated against any liquid already inside a valve.
- Legal moves and exact reserved commits both reject a parcel whose pigment does not match the destination key. This keeps sequential play, concurrent incoming pours, hints and the solver on one rule.
- Existing saves without the new field infer a valve key from their preloaded valve liquid (or an explicit target), while newly authored valves may start empty by supplying the key directly.
- Helpers remain ordinary bidirectional containers and cannot receive a valve key.

## Presentation

- Classic and 2D use a dedicated planar keyed-lid drawing with a visible hinge, highlight and redundant motif.
- 3D reuses depth-tested opaque lid geometry, adds keyed motifs in the cap shader and hinges the lid around its rim in vessel-local space. It continues to occlude correctly with moving glass.
- Ordinary completion stoppers are unchanged. Valve lids remain present whether their valve is empty, partial or complete.

## Validation

- All 15 Valve Lab boards solve under keyed rules. Catalog checks cover capacity, receive-only roles, keys, pigment inventory and the accepted empty Level 1 layout.
- Focused checks cover wrong-color rejection, matching-color acceptance, empty starts and key save/restore.
- Classic/2D/3D presentation captures include a completely empty keyed valve. The full small-capacity presentation suite passes.
- The three-presentation concurrent-pour suite passes, including shared valve receivers and projected capacity/color reservations.
- Live Mac verification confirmed the Tide lid, named wrong-color feedback, and the 2D lid opening fully during a matching pour. The pre-check Endless board was restored afterward.
