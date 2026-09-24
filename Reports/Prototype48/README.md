# Stable Sorting Course pilot — September 23

## Player experience

- **Sorting Course** is available from the Labs menu without replacing the sixteen hand-authored Sorting lessons.
- The pilot contains 25 numbered levels with Previous, Next, direct level selection, completion checkmarks, and a live `completed / 25` summary.
- Levels 5, 10, 15, 20, and 25 are Discovery levels with hidden units and retained discoveries.
- Quick pace uses the accepted 2.4× Sorting target; the instructional labs retain their existing pace.
- Course selection, each board, move history, and completion are saved independently from authored Sorting, Endless, and Valve Lab.

## Hybrid boundary

- The Original generator was used only as an offline authoring source.
- The 25 accepted starting boards are frozen in the app, so future generator changes cannot alter this progression.
- All gameplay, rendering, concurrent pours, Undo, hints, Discovery knowledge, and saving use the current Lab engine.
- Endless Sorting remains runtime-generated and unchanged.

## Validation

- Every frozen board is compared byte-for-byte at the model level with its recorded source mode, level, and generation variant.
- The Lab solver completes all 25 boards under their shipping rules, including all five hidden-unit Discovery levels.
- Session coverage verifies navigation, 2.4× Quick pace, checkpoint/relaunch, save isolation, Discovery teaching, and return to the authored Sorting Lab.
- Existing authored Lab, Journey, Endless, Valve, hint-route, concurrent-pour, and reset regressions remain green.
