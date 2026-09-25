# Sealed 2D surface normalization — September 25

## Reported symptom

On Sorting Course 46, a completed seven-unit vial could show a dark notch between the yellow liquid and its completion cap. The pour committed correctly and play continued normally; only the retained 2D particle surface was wrong.

## Cause and correction

- The concurrent-capable 2D path preserved the naturally simulated receiver surface after a successful commit. A tall, completely full receiver could rarely retain a narrow low spot even though every particle arrived.
- When the final pour touching a vessel has finished and the authoritative board says that vessel is complete, 2D now replaces only that vessel's particles with their canonical resting positions before displaying its cap.
- Partial fills and vessels participating in another active pour retain their simulated surfaces. Pour rules, quantities, animation timing, vessel geometry and Classic/3D presentation are unchanged.

## Validation

- A focused regression completes a seven-unit receiver through the live concurrent-capable 2D session and verifies every particle in the sealed vial matches its canonical full surface.
- The complete vessel presentation suite still passes, including portrait rows, Course 45's large Metal upload and long-pour reproductions, all three presentations, completed caps and small-capacity routes.
- macOS Debug and signed physical-iPad Debug builds pass. The corrected build was installed and launched on Eddie's M4 iPad.

## Environment handoff cleanup

The one-time `HANDOFF-NEW-MACHINE.md` migration note has served its purpose. Its durable facts now appear at the top of `HANDOFF.md`; stale migration status and commit claims were not retained.
