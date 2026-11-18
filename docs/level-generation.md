# Algorithmic level generation

`LevelGenerate` creates fixed puzzles offline using the shared engine and solver. Runtime gameplay never generates levels or uses an external service.

## Reproduce the prototype

The original prototype resources are the baseline in commit `24f3d16229624dcaecbbf7907a3a9678d107d0e5`. Reproduce the current revision with the current generator and that fixed baseline. Fetch the PR history so the baseline is available in a fresh clone after a squash merge:

```sh
git fetch origin refs/pull/7/head
mkdir PrototypeBaseline
git archive 24f3d16229624dcaecbbf7907a3a9678d107d0e5 Sources/ColorFlowCore/Resources | tar -x -C PrototypeBaseline
swift run -c release LevelGenerate --revise-prototype-from PrototypeBaseline/Sources/ColorFlowCore/Resources --seed 2026111701 --output PrototypeLevels
```

The output directory must not already exist. Review and copy all four output files (`levels.json`, `solutions.json`, `losing-branch.json`, `generation.json`) into `Sources/ColorFlowCore/Resources/`, then run `swift run -c release LevelCheck` and `swift test -c release`. Generation stages verified output before publishing it; failures do not replace resources.

The revision preserves all square definitions and re-audits each circular level with seed `2026111701 + levelID`. Existing circles are retained when they pass solving, fall witnesses, sampling, and losing-alternative requirements. Rejected circles are regenerated using the same per-level seed/profile. The revision first reorders each pair Circular → Square and assigns final IDs before sampling or regeneration. It replaces circular definitions at final IDs 5, 7, and 9; all square geometry and queues remain unchanged. Report revision metadata records the base seed, audited IDs, and replaced IDs. Definitions and all four output resources were reproduced byte-for-byte. `--prototype --seed 2026111701` remains available to generate a fresh entire prototype under current rules; it does not reproduce the preserved baseline squares.

The ten-level configuration is ordered, never shuffled. Each pair starts with a circular board, followed by its square partner:

| Levels | Difficulty | Circular geometry / larger-block cells | Square geometry / larger-block cells | Accepted random-play wins / 32 |
| --- | --- | --- | --- | --- |
| 1–2 | Easy | 10 lanes × 5 bands / 10 | 10 × 10 / 20 | 24–32 |
| 3–4 | Easy | 10 lanes × 5 bands / 12 | 10 × 10 / 24 | 20–27 |
| 5–6 | Medium | 10 lanes × 5 bands / 18 | 10 × 10 / 35 | 12–19 |
| 7–8 | Medium | 10 lanes × 5 bands / 20 | 10 × 10 / 40 | 8–15 |
| 9–10 | Hard | 10 lanes × 5 bands / 25 | 10 × 10 / 50 | 0–4 |

Easy and medium use three bucket slots and four colors; hard uses two slots and five colors. The circular sampling profile matches its square partner even though its absolute large-block area is smaller. Sampling is a reproducible selection heuristic, not a measure of human difficulty. Scores need not decrease between differently sized boards.

Square and circular generation policies own initial shape selection and board-specific acceptance. Packing, queue derivation, solving, and sampling remain shared. Square levels contain the complete difficulty shape family. Easy allows dominoes; medium adds 1 × 3, 3 × 1, and 2 × 2; hard also adds 2 × 3, 3 × 2, and 3 × 3. Circular levels sample a subset and include wide arcs. Logical capacity remains width × height regardless of position or displayed area.

The generator packs containers, derives queues using real engine transitions, and independently searches for a winning path within 25,000 visited states. Candidates must pass seeded sampling and replay validation. Medium/hard require a losing alternative. Each level gets at most 200 attempts; an inconclusive search or exhausted budget is an explicit failure, never proof of impossibility.

Every circular winning path must demonstrate a fall. The circular set must also demonstrate a partially filled falling arc and an exposed inner entry through an outer gap. `PathFeatures` checks actual engine events, and `LevelCheck` audits these witnesses alongside all ten wins and six losing alternatives.

## Metadata and other workflows

Report format 2 records batches, seed, ordering, attempts, solution lengths, visited states, and sampling results. Profiles now also record board kind, dimensions, logical large-block area, and the square-equivalent sampling area. Missing fields decode as legacy square configurations; format-1 reports remain readable. `authored` batches preserve their explicit order without a cross-level score constraint. Progressive and shuffled square workflows remain available:

```sh
swift run -c release LevelGenerate --seed 20261114 --output SquareLevels
swift run -c release LevelGenerate --difficulty medium --count 3 --output MediumLevels
swift run -c release LevelGenerate --append-from SquareLevels --count 6 --shuffle --seed 2026111702 --output ExpandedLevels
```

Append workflows preserve input IDs, definitions, queues, box order, and paths. Replacing published geometry or queues requires a save-version bump; the prototype uses version 6 and migrates version-4/5 statistics while resetting boards. The former 50-level catalog is retained in Git history.

Core tests use independent fixed fixtures. The published catalog is covered separately by `LevelCheck`; use `--solve` for fresh catalog-wide searches after solver changes. Hints verify stored continuations against the exact current state, then fall back to cancellable search with a ten-second deadline. A timeout leaves solvability unknown.

Circular targeting uses the aligned lane in engine state. Each target receives a fresh clockwise scan from the current alignment, including after clearing and inward settling. Solver state identity includes alignment; hints verify the same complete state.
