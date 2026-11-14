# Validation status

November 14, 2026; Xcode 27.2, iOS 17 deployment target.

- `swift test -c release`: 36 tests passed in approximately 1.3 seconds after building. Fixed fixtures cover engine rules, persistence, solver outcomes, hint targets, cancellation/deadlines, and reproducible generation independently of the published catalog.
- `swift run -c release LevelCheck`: all nine stored winning paths and six losing alternatives replay correctly; generation metadata matches the campaign. `--solve` also independently found winning paths for every level.
- Generator checks confirmed fresh unseeded results, seed reproducibility across debug/release builds, and refusal to overwrite existing output.
- `python3 scripts/test_device_selection.py`: all 10 runner checks passed.
- `python3 scripts/run-tests.py`: 14 UI tests passed on each destination below, with zero failures, skips, or runtime warnings. The routine suite checks representative layouts, progression/completion, settings/hints, locks, retry, restoration, animation locking, Reduce Motion, and splash return.

| Destination | Result |
| --- | --- |
| iPhone SE third-generation simulator, iOS 27.2 | 14/14 UI tests passed |
| Physical iPhone SE second generation, iOS 17.1.1 | 14/14 UI tests passed |
| iPhone 18 Pro simulator, iOS 27.2 | Native fixed-fixture suite and final cartoon hint check passed (27 tests) |

Final artwork and the 56 × 56-point settings button passed three focused checks on both the physical SE and compact simulator, plus the larger-phone hint check. These focused runs followed the routine suite and did not replay the campaign.

The later false-timeout fix uses a single hint presentation state. `testHintsShowLoadingUntilResultIsReady` holds the empty startup state pending, verifies the spinner is visible and timeout text absent, then checks that verified hints appear. The regression passed on both the physical SE and compact simulator in `TestResults/hint-startup-regression-device.xcresult` and `hint-startup-regression-simulator.xcresult`. It is included in the routine suite, which now contains 15 UI tests; the baseline 14-test run above preceded this added regression.

The complete nine-level UI journey also passed on the SE simulator during development. It is now an optional `--full-campaign` release check, not part of routine visual validation. Whole-catalog proof replay belongs in `LevelCheck`; routine core tests use three fixed test-only levels.

The campaign was generated with seed `20261114`:

| Level | Difficulty | Slots | Larger-box area | Winning moves | Random-play wins / 32 |
| --- | --- | ---: | ---: | ---: | ---: |
| 1 | Easy | 3 | 20% | 81 | 24 |
| 2 | Easy | 3 | 24% | 88 | 24 |
| 3 | Easy | 3 | 30% | 78 | 16 |
| 4 | Medium | 3 | 35% | 63 | 13 |
| 5 | Medium | 3 | 40% | 69 | 11 |
| 6 | Medium | 3 | 45% | 56 | 6 |
| 7 | Hard | 2 | 50% | 72 | 0 |
| 8 | Hard | 2 | 55% | 69 | 0 |
| 9 | Hard | 2 | 60% | 73 | 0 |

These are algorithmic progression heuristics; human difficulty still needs playtesting. A verified winning path proves solvability, while an inconclusive search or timed-out hint proves neither solvability nor impossibility.

Routine simulator/device reports are in `TestResults/20261114-143042/`. Native fixture and cartoon-hint checks are in `TestResults/cartoon-river-fixtures-large.xcresult`. Final focused reports are `TestResults/paint-river-reference-device.xcresult`, `paint-river-reference-simulator.xcresult`, and `paint-river-reference-large.xcresult`. Inspected captures are linked from [visual evidence](evidence/README.md). Raw reports remain ignored because they contain device identifiers. Xcode project regeneration is reproducible and retains screenshot recording.
