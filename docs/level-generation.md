# Algorithmic level generation

`LevelGenerate` creates fixed puzzles offline using the shared engine and solver. The app reads the bundled campaign.

## Reproduce the 50-level campaign

```sh
swift run -c release LevelGenerate --mixed-campaign --seed 2026112002 --output MixedCampaign
```

Use a new output directory. Compare `levels.json`, `solutions.json`, `losing-branch.json`, and `generation.json` with the bundled copies. When publishing a replacement, copy all four files into `Sources/ColorFlowCore/Resources/` and run `swift run -c release LevelCheck` and `swift test -c release`. Generation stages verified output before publishing it.

The seed shuffles 25 pairs. Each pair keeps its circular board first and uses the same difficulty for both boards. The campaign includes 20 easy, 20 medium, and 10 hard levels. Each profile below contributes five pairs.

| Difficulty | Circular large-block cells | Square large-block cells | Random-play wins accepted out of 32 |
| --- | ---: | ---: | ---: |
| Easy | 10 | 20 | 24–32 |
| Easy | 12 | 24 | 20–27 |
| Medium | 18 | 35 | 12–19 |
| Medium | 20 | 40 | 8–15 |
| Hard | 25 | 50 | 0–4 |

Circular boards have ten lanes and five bands. Squares use 10 × 10. Easy and medium use three bucket slots and four colors. Hard uses two slots and five colors. The random-play results guide candidate selection and difficulty labels remain provisional until playtesting.

Square and circular generation policies select their initial shapes. Square levels include the complete difficulty shape family. Circles sample a subset and include wide arcs. Both use the same packing, paint queue derivation, solver, and sampling. The default budget is 200 attempts per level and 25,000 visited search states per candidate.

`LevelCheck` reconstructs the profile order from the recorded seed, checks unique definitions, and replays every winning path and every medium and hard losing path. Each circular winning path demonstrates a fall. Across the circular levels, the audit also requires a partially filled falling tray and an inner entry exposed through an outer gap. A search that reaches its limit leaves solvability unknown.

## Other workflows

Report format 2 records batches, seed, ordering, attempts, solution lengths, visited states, and sampling results. Profiles record board kind, dimensions, logical large-block area, and the square-equivalent sampling area. Format-1 square reports remain readable.

The [ten-level prototype](https://github.com/ffeltrinelli/color-flow-ios/tree/5cefd62) and older square campaigns are in Git history. The generator retains `--prototype` and `--revise-prototype-from` for historical reproduction. Progressive and shuffled square generation are also available.

```sh
swift run -c release LevelGenerate --seed 20261114 --output SquareLevels
swift run -c release LevelGenerate --difficulty medium --count 3 --output MediumLevels
swift run -c release LevelGenerate --append-from SquareLevels --count 6 --shuffle --seed 2026111702 --output ExpandedLevels
```

Append workflows preserve existing IDs, definitions, queues, box order, and proof paths. Replacing published geometry or queues requires a save-version bump. Version 7 preserves lifetime statistics from versions 4–6 and starts the new campaign at level one.

Core tests use independent fixtures. Use `LevelCheck --solve` for a fresh catalog-wide search after solver changes. Runtime hints first verify stored continuations against the exact saved state, including circular alignment, then fall back to cancellable search with a ten-second deadline.
