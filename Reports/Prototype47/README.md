# Hint recovery — September 23

## Behavior

- When Hint cannot find a legal route from the current position and Undo history exists, the Lab now offers **Undo until a hint is available**.
- Accepting the offer searches a copy of the history first, then rewinds the real board directly to the nearest earlier solvable position and displays its hint.
- The board never animates or flashes through intermediate Undo states.
- Cancel leaves the board unchanged. If even the initial position has no hint, the player is told explicitly.
- Discovery knowledge remains revealed during recovery, matching ordinary Undo behavior.

## Scope and architecture

- The behavior lives in the shared Lab session, so it applies to authored labs, Endless Sorting and Discovery, and Valve Lab.
- Route solving remains off the main actor. No Original-game controller, hint, or asynchronous code was adopted.
- Classic, 2D Fluid, and 3D Fluid restore through the same existing Undo state paths before the recovered hint is presented.

## Validation

- A deterministic receive-only target fixture makes a legal losing pour, verifies the recovery offer, accepts it, and confirms the exact earlier solvable state and expected hint.
- Existing Valve catalog equivalence and all fifteen Valve solutions remain covered.
- Full application compilation and the established hint, Discovery, Endless, and concurrency regressions remain required before synchronization.
