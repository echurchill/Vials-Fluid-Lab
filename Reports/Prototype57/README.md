# Prototype 57 — compact iPhone board controls

## Outcome

The Lab board now has an intentional phone interface instead of allowing the iPad control rows to compress and wrap.

- At widths below 500 points, Journey, Sorting Course, Endless and the individual labs live in one game-mode menu whose label always shows the current destination.
- Presentation and pace become two compact menus that continue to show the active choice. The level browser remains directly available beside them.
- Undo, Hint, Pause, Reset and post-completion actions retain their full hit areas but use icon-only labels on phone.
- Dense interface symbols use bounded sizes so large Dynamic Type settings cannot expand the board beyond the display. Status and instructional text remain readable.
- iPad and Mac retain their existing expanded buttons, segmented presentation control and segmented pace control.

## Validation

- macOS Debug build passed.
- iPhone Simulator Debug build passed for an iPhone 17e.
- Portrait visual inspection passed at the standard text size.
- Portrait visual inspection passed at Accessibility Extra Large: the interface remained within the safe width, navigation did not wrap, the helper card remained contained and all five footer actions retained distinct touch targets.
- Full vessel-presentation regression passed, including all render modes, adaptive rows, large-vial pours and Course 45 coverage.
- All 18 cross-lab/presentation concurrency cases plus density, Discovery and machine-exclusivity checks passed.
- The complete 100-level Sorting Course validation passed.

The compact path is selected from actual available width, so it also applies naturally to future narrow iPhone sizes without device-name checks.
