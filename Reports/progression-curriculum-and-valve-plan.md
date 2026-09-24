# Progression, Scoring, And Valve-Beaker Plan

## Purpose

Build a calm mastery layer around the existing deterministic level generator, then introduce one new puzzle rule without destabilizing the core liquid-sort game.

The work is intentionally staged. Scoring must never make hints, Undo, restarting, or the helper beaker feel like punishments. The level curriculum must make the three modes legible before the first new container rule appears.

## Non-Goals

- Do not charge moves, drops, or currency for tools.
- Do not make a missed mastery target erase a player's permanent record.
- Do not introduce real-fluid simulation as part of this plan.
- Do not let generated levels use a new rule until authored teaching levels prove the rule is understandable.

## Phase 1: Persistent Result Model

### Store per-level results

Add a persistent result record keyed by the deterministic level identity:

- Mode.
- Level number.
- Zen salt only for Zen levels.

Each record should retain:

- Completion state.
- Best move count.
- Best known minimum move count when the solver has one.
- Best mastery tier.
- Number of completions.
- Whether the result was hint-assisted, as analytics only.

The current tester rating record should remain separate from permanent player progress. It is temporary research data, not a player-facing grade.

### Minimum-move source

Use the existing breadth-first solver only for levels where it finishes within its budget. The game must call a value `Best known` rather than `Par` whenever the minimum is not proven. Later, generator precomputation can cache exact values for curated levels and for generated levels that finish quickly.

## Phase 2: Mastery Result And Flow Multiplier

### Base mastery

Every completed level gives a permanent completion result. Mastery compares the player's move count with the proven or best-known target.

| Mode | Strong target | Good target | Completion target |
|---|---:|---:|---:|
| Easy | at or below target | target + 2 | target + 5 |
| Medium | at or below target | target + 3 | target + 7 |
| Hard | at or below target | target + 4 | target + 9 |

Results should be shown as one, two, or three droplets on the win celebration. A player can improve a level later; a lower later result never overwrites a previous higher result.

### Flow multiplier

Flow is a temporary bonus layer separate from personal bests.

- A top mastery result adds two Flow links.
- A middle mastery result adds one Flow link.
- A completion outside mastery grants its normal completion reward but does not add a link.
- Every three links raises Flow by one tier: `1x`, `1.25x`, `1.5x`, `1.75x`, then `2x` maximum.
- Hints do not add Flow links, but they do not reset Flow.
- Restarting or a non-mastery completion reduces Flow by one tier at most. It never resets to zero from a single disappointing level.

Mode weights make Hard accomplishments more meaningful without making Easy irrelevant:

| Result | Easy links | Medium links | Hard links |
|---|---:|---:|---:|
| Top mastery | 2 | 3 | 4 |
| Middle mastery | 1 | 2 | 3 |
| Completion | 0 | 0 | 1 |

### Presentation

Keep Flow off the active play board. Show it only in the win celebration as a row of droplets filling toward the next multiplier. The celebration should say what happened in plain language, for example `Great route · Flow 1.5x`.

### Acceptance criteria

- A player can use Undo, Restart, a hint, or the helper beaker without losing a prior best result.
- The app never shows an exact par unless the solver proved it.
- A completion outside mastery remains visibly successful.
- Flow is understandable from one win screen without a tutorial panel.

## Phase 3: Hybrid Level Curriculum

### Curriculum data

Replace the single continuous formula with mode-specific progression beats. A beat declares:

- First and last level number.
- Color count range.
- Capacity range.
- Empty-vial count.
- Duplicate-color target count.
- Whether heights may vary.
- Scramble-depth range.
- Target minimum-move band.
- Whether the level is an authored anchor, breather, or challenge.

The generator remains deterministic between anchors. It must reject candidates outside the beat's solvability and target-move constraints.

### Easy curriculum

1. Levels 1–10: three colors, 3–4 unit uniform vials, one empty vial, shallow scrambling.
2. Levels 11–25: introduce four and then five colors, then the second empty vial when it enables rather than trivializes play.
3. Levels 26–40: full-color layouts, longer top runs, and occasional challenge levels previewing the next beat.

Easy has no duplicate-color targets and no mixed vial heights. Its purpose is confidence, pattern recognition, and recovery from mistakes.

### Medium curriculum

1. Levels 1–12: uniform four-unit vials with the first repeated-color destinations.
2. Levels 13–30: higher capacity, more duplicate targets, and deliberate top-run traps.
3. Levels 31+: larger inventories with two empty vials and deeper but readable scrambling.

Medium uses duplicate colors as its identity, but it should keep container geometry stable.

### Hard curriculum

1. Levels 1–12: variable heights introduced with familiar color counts.
2. Levels 13–25: variable heights combined with duplicate targets and constrained empty space.
3. Levels 26+: taller vessels, mixed capacities, deeper scrambles, and later the valve-beaker prototype.

Hard adds one meaningful constraint at a time. A tall vessel, duplicate target, and new container rule should never all debut in the same level.

### Breathers and challenges

Each mode keeps its existing deterministic exception rhythm, but the exception levels become authored anchors:

- A breather borrows the previous beat's constraints and has a lower target-move band.
- A challenge borrows the next beat's constraints, but only one new variable is introduced.
- The visible subtitle names both the actual level and the borrowed tuning level.

### Anchor-level process

1. Draft a level specification from its beat.
2. Solve it manually and with the solver.
3. Record the exact minimum, target band, intended insight, and expected common mistake.
4. Add it to a regression fixture.
5. Place generator-built levels between anchors only after the anchor's player feedback is positive.

### Acceptance criteria

- Testers can describe the difference among Easy, Medium, and Hard after playing each for ten levels.
- No generated level starts partially filled.
- Each beat has at least one regression-tested anchor level.
- New heights and duplicate targets arrive before the valve-beaker rule.

## Phase 4: Receive-Only Valve Beaker

### Rule

The first new mechanic is a receive-only valve beaker. It accepts normal pours but cannot be selected as a source. Once filled with one fluid, it is a final destination just like a completed vial.

This is preferred over a reactive-fluid rule because it is legible, deterministic, easy to validate, and creates strategic commitment without physics simulation.

### Visual language

- The current subtle rim line and downward arrow are provisional and should be replaced by a physical, color-keyed lid.
- The lid color identifies the only pigment that valve accepts. Pair color with a matching pattern or symbol so the rule remains readable without color perception.
- The lid stays visibly closed for an invalid pigment, opens during a valid incoming pour, and closes again afterward.
- The valve may begin completely empty because the lid, rather than preloaded liquid, declares its target pigment.
- Its receiving state uses the normal liquid rendering. Completion requires the valve to be filled to capacity with its keyed pigment.
- An attempted outgoing pour retains the existing invalid feedback; the valve remains receive-only.
- The helper beaker never receives the valve rule.

This is a future Valve Lab revision, not the current behavior. It requires explicit accepted-pigment metadata rather than inferring the commitment from the valve's existing top liquid. The hint solver, generator, save format, concurrent reservation rules, and all three renderers must use that same metadata. Once the lid is legible in testing, remove the redundant arrow/rim marker.

### Model and solver changes

1. Add `ContainerRule.normal` and `ContainerRule.receiveOnly` to the vial model.
2. Update legal-move calculation: a receive-only container may be a destination but never a source.
3. Update the hint solver, minimum-move solver, and dead-end recovery solver to apply the rule.
4. Add rule-aware generated-level validation.
5. Keep the ordinary generated catalog valve-free until authored teaching levels pass testing.
6. Add accepted-pigment metadata and validate empty-start valves, wrong-color rejection, lid animation, saves, hints, Undo and concurrent incoming reservations.

### Prototype level sequence

1. Teaching level: one obvious receive-only final destination.
2. Teaching level: choose between two colors before filling the valve.
3. Combination level: duplicate-color target plus one valve.
4. Combination level: variable-height vessel plus one valve.
5. Breather: an easy win using the valve rule.
6. Capstone: two valves, introduced only after the first five test well.

### Acceptance criteria

- Players identify the rule from the visual treatment without explanatory prose.
- The solver proves every valve level solvable without the helper beaker.
- Hints never recommend pouring out of a receive-only valve.
- A wrong valve commitment can be detected as a dead end and recovered through the existing rewind feature.

## Rollout Order

1. Gather tester feedback through the temporary in-app ratings screen.
2. Add persistent completion and best-move results.
3. Add mastery droplets and Flow only after target bands are trustworthy.
4. Implement the curriculum beat data and first anchor levels.
5. Prototype the receive-only valve with its six authored levels.
6. Review tester feedback before enabling valves in generated Hard levels.
