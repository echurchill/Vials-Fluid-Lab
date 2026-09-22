# Prototype 41 — Journey

## Implemented

Journey is a new entry beside the labs. It opens a scrollable learning map with 19 existing teaching puzzles, each with a learning goal, completion state and current-stop marker. This pass curates and connects existing boards; it does not introduce new puzzle layouts or mechanics.

Sorting (First sort → Cross currents) branches to Density, Mixing, or optional Discovery. Mixing continues to Recovery. The Density and Recovery paths both suggest the combined challenges in Crossover. Discovery ends as its own optional branch. Every stop remains accessible; prerequisites are suggested learning order, not locks.

On a Journey board, the reserved completion action follows the path across labs. A fork offers Choose path; an end offers Journey map. The initial footer teaches that stop's concept, then normal move/hint feedback takes over. Explore labs exits Journey to direct lab play, including the current lab. Existing direct lab Next/Choose level behavior is preserved.

Journey shares the same saved puzzle state, Undo history and completion checks as the labs. A backward-compatible journeyMode save field retains navigation context; older saves default to direct lab play. New users and Reset all progress start with First sort in Journey. Diagnostic trials remain isolated and default to direct labs. Selecting a stop never silently resets it.

## Validation

- Final Mac Release and signed iOS Release builds passed.
- Journey validation passed: all 19 stops solvable and reachable; unique nodes, no cycles/dangling edges, optional Discovery, Sorting fork, cross-lab bridges, same-lab exit, direct puzzle escape, presentation switching, shared progress, save/reload, legacy save migration, in-flight navigation guard, and fresh reset.
- Existing session suite passed all 19 experimental levels and lab persistence checks.
- Wide (1000 points) and compact (650 points) map content rendered and visually inspected. The attached images use illustrative completed/current stops. They are offscreen content renders, not live device screenshots. ImageRenderer does not capture the native ScrollView, so the reusable map content is rendered directly.
- git diff --check passed. Physics/rendering/geometry files remain unchanged from 505b0dd.

## Live Mac checks (September 21)

Caffeinate was active. The app was exercised through its actual accessible controls, using ordinary saved progress rather than a completed-state fixture.

- Opened, scrolled and selected stops in Journey; all 19 stops exposed their learning goals and completion states. Added an explicit button accessibility trait and verified it after rebuilding/relaunching.
- Completed Second chance in 3D Fluid using Separate and Mix. Next: Equal partners crossed into Crossover with Journey context intact. Explore labs → Crossover exited Journey without resetting the board.
- Completed Cross currents in Classic in seven pours. Choose path offered Density, Mixing and optional Discovery; selecting Discovery opened First reveal. The map reflected completed/current stops.
- Completed Full spectrum in 2D Fluid in 11 operations, including concurrent pours into the mixer inputs. The terminal Journey map button opened the map with Full spectrum marked completed/current and four stops complete. Closing the map returned to the solved board without changing progress.
- Both final Mac Release and signed iOS Release builds passed after the accessibility correction.

Mac screenshot capture returned undersized, distorted window previews. A Dock activation attempt timed out; direct game accessibility access recovered. Therefore these are live interaction/accessible-state checks, supported by the inspected wide/compact offscreen renders, not full-resolution live visual acceptance of spacing or animation. iPad portrait/landscape visual checks remain pending: the device was unavailable during this follow-up and was not accessed. A previous signed build had been installed before this follow-up; the final accessibility-only correction has been compiled for iOS but not installed.

The unrelated root PNG and paused performance automation were left untouched. No vial geometry, fluid simulation, camera or pour animation implementation changed.
