# Reset all progress

Open the ellipsis **Board options** menu and choose **Reset all progress…**. A confirmation explains that this clears saved puzzles, completion marks, undo history, and bundled Original game progress, scores, and ratings. Cancel preserves the current board.

Confirming starts First sort at Level 1, with 3D Fluid and Relaxed pacing. All 12 authored puzzles return to their initial state. Sound, haptics, fluid-detail preferences and diagnostic report files are retained. The separately installed original Vials app is unaffected.

Active pours and pending worker results are cancelled. The bundled Original game also invalidates delayed pour completion and detached level-preparation results, preventing callbacks from an older run from recreating cleared progress.

## Validation

- The isolated-defaults regression passes in Classic, 2D Fluid and 3D Fluid. It seeds completed progress and undo, resets during two concurrent pours, checks all 12 initial boards, checks persistence/reload and legacy-store removal, and verifies retained preferences. [Output](validation.log).
- Actual Mac UI automation used a disposable app copy with a separate bundle identifier and defaults domain. It selected Confluence, opened the menu and confirmation, verified Cancel retained Confluence, confirmed Reset returned First sort with zero moves/completions, and verified that state after app relaunch. The normal app's progress was not reset. `caffeinate -di` kept the Mac awake throughout UI testing.
- macOS Release and signed iOS Release builds pass. The iOS build includes the previous smoother-glass change; installation and device checks remain pending iPad availability.

Reproduce the state regression with:

```sh
bash Scripts/validate_reset_progress.sh path/to/default.metallib
```
