# Algorithmic level generation

`LevelGenerate` randomizes layouts, color assignments, paint quantities, and queue placement offline. It uses no large language model (LLM), network, or external service. The app plays a fixed bundled campaign and only invokes the shared solver for hints.

```sh
swift run -c release LevelGenerate --output GeneratedLevels
swift run -c release LevelGenerate --seed 20261114 --output ReproducedLevels
swift run -c release LevelGenerate --difficulty medium --count 3 --output MediumLevels
```

Without `--seed`, the tool chooses and records a fresh 64-bit seed. A supplied seed reproduces generation for the same generator version and configuration. The default is a nine-level campaign. With a difficulty, count defaults to three; counts beyond three repeat that group's final profile. Output directories must not already exist. Generation finishes and verifies every level before staging files and renaming the completed directory, so failure cannot overwrite a published campaign.

The output contains `levels.json`, `solutions.json`, `losing-branch.json`, and `generation.json`. Review these files, then copy all four into `Sources/ColorFlowCore/Resources/`. Run `swift run -c release LevelCheck` and `swift test -c release`. Publishing changed geometry, box order, or queues requires a save-version bump; campaign version 4 already resets older saves to level one.

## Difficulty and acceptance

| Group | Buckets | Colors | Larger-box area across three levels | Random-play wins accepted out of 32 |
| --- | ---: | ---: | --- | --- |
| Easy | 3 | 4 | 20%, 24%, 30% | 24–32, 20–27, 16–23 |
| Medium | 3 | 4 | 35%, 40%, 45% | 12–19, 8–15, 4–11 |
| Hard | 2 | 5 | 50%, 55%, 60% | 0–4 |

Sampled wins must also never increase along the generated sequence. Easy's 24% replaces the originally proposed 25% because its 1 × 2 and 2 × 1 shapes occupy even areas. Medium adds 1 × 3, 3 × 1, and 2 × 2; hard adds 2 × 3, 3 × 2, and 3 × 3. Each level includes its complete shape family and covers exactly 100 cells with exactly matching paint supply.

Random-play sampling chooses uniformly among legal actions for 32 seeded runs. This is a reproducible selection heuristic, not a model of human reasoning or a proof of human difficulty. Geometry and the two-bucket constraint continue progression within hard even when all samples lose. Human playtesting is still needed.

The generator first packs rectangles, then derives a paint-consumption schedule using actual engine targeting and gravity. Assigning these tins to random queues preserves a chronological winning witness while introducing alternative choices. Acceptance independently requires the shared solver to find a full path within 25,000 visited states, and replays every move while validating paint conservation and settled geometry. Medium and hard additionally require a sampled losing path. Each level gets at most 200 candidate attempts; exhaustion is an explicit failure. Duplicate definitions are rejected without considering their campaign IDs.

`generation.json` records the seed, profiles, attempts, solution lengths, search-state counts, and sampled wins. The bundled campaign uses seed `20261114`. For focused core tests, generation accepts explicit attempt and search limits. Hints first replay the bundled winning path and reuse its continuation when the exact current state matches. Invalid or nonmatching paths fall back to the same stable, pour-first search. Runtime hints use a ten-second deadline with a loading wheel and cancellation instead of a state-count cutoff. Offline generation remains bounded by visited-state counts for reproducibility; a timed-out hint remains inconclusive, never proof of a dead end.

## Validation as the catalog grows

Routine core tests load three fixed fixtures from the test target, not the published campaign. Their engine, hint, persistence, and solver coverage stays bounded as levels are added. Newly generated levels are checked before export. The separate `LevelCheck` command audits every published winning path, losing alternative, and generation report; replaying a valid winning path proves solvability without searching again. Run this audit whenever level data changes and in release validation. Use `--solve` for a fresh catalog-wide search when changing the solver; it is intentionally separate from routine unit tests.
