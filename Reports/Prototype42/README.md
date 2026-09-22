# Prototype 42 — teaching bridges and contextual guides

## Progression review

The previous 19-stop Journey assumed that either Density or Recovery prepared a player for Equal partners. In practice, Density did not teach the mixer, and neither route isolated density-changing chambers. Split purple also led straight to a two-machine recovery puzzle, and Discovery jumped from two colors to three deep colors.

Journey now has 24 stops:

- Both main branches meet at **Ready to blend**: three vials, prefilled mixer inputs, one activation. This teaches or refreshes the recipe operation without transport or density adjustment.
- **One step heavier** and **Float again** each use three vials and three operations: load a chamber, activate it, deliver to a target. The same blue pigment makes density, rather than color, the lesson. These precede Equal partners.
- Recovery now includes the existing **Room for both** between Split purple and Second chance. Clear a blocked separator output before combining machines.
- Discovery adds **Third color**, with two-unit vials and three colors, before the three-unit Hidden garden.

Four new puzzles also appear in their direct labs. Existing puzzle identifiers and starting boards are unchanged, so saved states remain valid; numbering naturally reflects the inserted lessons. All paths remain open.

## First-use help

A question-mark button beside the board options replays explanations relevant to the current puzzle. The first encounter with hidden liquids, density symbols, a mixer, separator, heavier chamber or lighter chamber opens a short popover. Multiple new concepts are paged with Next tip; players can close at any time. The same core tool explanation is also included in the existing machine information popover, alongside its actual route and readiness checks.

Seen-topic identifiers persist in the existing save, shared by Journey and direct labs. Old saves default to no topics seen; unknown future identifiers do not invalidate a save. Ordinary puzzle reset preserves teaching history; Reset all progress clears it. First-use help waits for navigation dismissal, does not interrupt a running or partially played board, and is suppressed in diagnostic trials. The guide suspends scene updates and resumes according to the player's pause state.

No geometry, camera, shader, physics or pour-animation source was changed. SwiftUI board layout was extracted into a computed view to keep the compiler within its expression type-checking limit; its layout modifiers are preserved.

## Verification

- Graph/session validation: all 24 stops solvable/reachable, both main branches pass through isolated tool lessons, optional Discovery remains terminal, shared progress, navigation and legacy saves pass.
- Guide tests: context filtering, persistence, replay availability, Journey/lab sharing, ordinary/full reset, old saves and unknown future topics pass.
- The experimental session suite executes every Density, Mixing, Recovery and Crossover board, including the new bridges, with hints, completion and Undo checks (22 boards).
- Wide and compact map content plus all six guides have reproducible offscreen renders; these are not device screenshots.
- Final Mac and signed iOS Release builds passed, including the final introduction guard. iPad remains unavailable and has not been accessed.

### Live UI status

The Mac was locked when UI automation selected the rebuilt app, and automatic unlock failed. A manual-unlock request is pending. Caffeinate was running, but it cannot unlock an already locked screen. No live UI acceptance is claimed for this update. Remaining checks: first-use presentation after closing Journey, Next tip/Got it/close, replay, no repeat on revisiting, and completion through the new bridge sequence. iPad checks remain deferred. Changes are local and not pushed.

## September 22 follow-up — async GPU warning and resumed checks

Replaced `command.waitUntilCompleted()` in async `profileDensitySurface()` with `await command.completed()`. The command buffer is already committed by `encodeFrame`; status/errors and GPU timing are still checked after completion. This fixes the Swift concurrency warning and releases the main actor while the optional profiler waits. Normal render/simulation waits were not changed. Both Release builds pass and the reported warning is absent; Xcode still emits its unrelated App Intents metadata-extraction message. Logs: `/tmp/vials-async-gpu-mac.log`, `/tmp/vials-async-gpu-ios.log`.

The updated signed build was installed and launched on the reconnected M4 iPad. No physical-iPad visual acceptance or GPU profiling result is claimed yet. QuickTime opened a file picker rather than an iPad preview, so no device screenshot was inspected and no recording was made.

Live Mac checks resumed: Ready to blend automatically showed its mixer guide after Journey selection, Got it dismissed it, the recipe completed, and Next opened One step heavier. That level showed density/chamber pages, Next tip/Got it worked, all three operations completed and Next: Float again appeared. The ? replay button and explicit close worked. Native screenshots remain undersized previews. Remaining checks: non-repetition on revisit/relaunch, Float again and Discovery introductions, iPad portrait/landscape. Changes remain local/unpushed.
