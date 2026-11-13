# Validation status

Validated on November 13, 2026, using Xcode 27.2 and an iOS 17 deployment target.

- `swift test`: 18 passing core tests cover automatic top-down targeting, paint conservation, blocked leftovers and manual resumption, recharge, outcomes, authored solutions and losing paths, version-1 reset, and exact version-2 restoration, including wins and losses.
- `swift run LevelCheck`: all three fixed 10 × 10 levels have verified winning paths. Medium and hard also have replayed losing alternatives.

| Level | Provisional difficulty | Slots | Winning-path moves | Solver states visited |
| --- | --- | ---: | ---: | ---: |
| 1 | Easy | 3 | 74 | 504 |
| 2 | Medium | 2 | 79 | 335 |
| 3 | Hard | 2 | 89 | 5,719 |

Search counts describe one solver strategy, not human difficulty. Human playtesting is still needed to calibrate the labels.

| Destination | Result |
| --- | --- |
| iPhone SE third-generation simulator, iOS 27.2 | Complete suite passed: 18 core tests and nine UI tests |
| iPhone 17 simulator, iOS 27.2 | Updated normal-pour timing test passed; recording inspected |
| Physical iPhone SE second generation, iOS 17.1.1 | All nine UI tests passed with the faster timing |

The UI suite covers the complete three-level journey and Start Again, medium/hard defeat and retry, recharge, blocked buckets, read-only board layout, exact restoration, restart confirmation, interruption during a normal pour, and reduced motion. A normal nine-block pour must remain visible for at least four seconds.

`python3 scripts/run-tests.py` passed both simulator and device stages. Results are in `TestResults/20261113-232908/simulator.xcresult` and `device.xcresult`. The larger-phone timing check is in `TestResults/top-down-faster-pour.xcresult`. Raw bundles remain ignored because they contain device identifiers.

Inspected before/after screenshots and the final pour recording are linked in [visual evidence](evidence/README.md). The shared test scheme still uses screenshots; animation evidence was recorded separately. Test sessions use isolated saves, preserving normal play progress. No test-runner logic changed.
