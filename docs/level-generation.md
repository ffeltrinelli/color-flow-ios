# Algorithmic level generation

`LevelGenerate` creates fixed puzzles offline using the shared engine and solver. Runtime gameplay never generates levels or uses an external service.

## Reproduce the prototype

```sh
swift run -c release LevelGenerate --prototype --seed 2026111701 --output PrototypeLevels
swift run -c release LevelCheck
swift test -c release
```

The output directory must not already exist. Review and copy all four output files (`levels.json`, `solutions.json`, `losing-branch.json`, `generation.json`) into `Sources/ColorFlowCore/Resources/` before auditing. Generation stages the complete verified output before publishing it; failures do not replace resources.

The ten-level configuration is ordered, never shuffled:

| Levels | Difficulty | Square geometry / larger-block cells | Circular geometry / larger-block cells | Accepted random-play wins / 32 |
| --- | --- | --- | --- | --- |
| 1–2 | Easy | 10 × 10 / 20 | 10 lanes × 5 bands / 10 | 24–32 |
| 3–4 | Easy | 10 × 10 / 24 | 10 lanes × 5 bands / 12 | 20–27 |
| 5–6 | Medium | 10 × 10 / 35 | 10 lanes × 5 bands / 18 | 12–19 |
| 7–8 | Medium | 10 × 10 / 40 | 10 lanes × 5 bands / 20 | 8–15 |
| 9–10 | Hard | 10 × 10 / 50 | 10 lanes × 5 bands / 25 | 0–4 |

Easy and medium use three bucket slots and four colors; hard uses two slots and five colors. The circular sampling profile matches its square partner even though its absolute large-block area is smaller. Sampling is a reproducible selection heuristic, not a measure of human difficulty. Scores need not decrease between differently sized boards.

Square levels contain the complete difficulty shape family. Easy allows dominoes; medium adds 1 × 3, 3 × 1, and 2 × 2; hard also adds 2 × 3, 3 × 2, and 3 × 3. Circular levels sample a subset and include wide arcs. Logical capacity remains width × height regardless of position or displayed area.

The generator packs containers, derives queues using real engine transitions, and independently searches for a winning path within 25,000 visited states. Candidates must pass seeded sampling and replay validation. Medium/hard require a losing alternative. Each level gets at most 200 attempts; an inconclusive search or exhausted budget is an explicit failure, never proof of impossibility.

Every circular winning path must demonstrate a fall. The circular set must also demonstrate a partially filled falling arc and an exposed inner entry through an outer gap. `PathFeatures` checks actual engine events, and `LevelCheck` audits these witnesses alongside all ten wins and six losing alternatives.

## Metadata and other workflows

Report format 2 records batches, seed, ordering, attempts, solution lengths, visited states, and sampling results. Profiles now also record board kind, dimensions, logical large-block area, and the square-equivalent sampling area. Missing fields decode as legacy square configurations; format-1 reports remain readable. `authored` batches preserve their explicit order without a cross-level score constraint. Progressive and shuffled square workflows remain available:

```sh
swift run -c release LevelGenerate --seed 20261114 --output SquareLevels
swift run -c release LevelGenerate --difficulty medium --count 3 --output MediumLevels
swift run -c release LevelGenerate --append-from SquareLevels --count 6 --shuffle --seed 2026111702 --output ExpandedLevels
```

Append workflows preserve input IDs, definitions, queues, box order, and paths. Replacing published geometry or queues requires a save-version bump; the prototype uses version 5 and migrates version-4 statistics while resetting boards. The former 50-level catalog is retained in Git history.

Core tests use independent fixed fixtures. The published catalog is covered separately by `LevelCheck`; use `--solve` for fresh catalog-wide searches after solver changes. Hints verify stored continuations against the exact current state, then fall back to cancellable search with a ten-second deadline. A timeout leaves solvability unknown.
