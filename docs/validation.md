# Validation status

Mixed-size boxes and splash update, November 14, 2026, using Xcode 27.2 with an iOS 17 deployment target.

- `swift test`: 26 core tests pass, including all nine rectangle sizes, partial fills, top-edge access, simultaneous gravity, bridging support, event replay, paint conservation, old-save resets, and exact version-3 restoration.
- `swift run LevelCheck`: all three authored 10 × 10 levels have winning paths. Every stored path conserves paint; medium and hard also have replayed losing alternatives.
- The app builds for Simulator with the selected launcher icon and revised splash assets.

| Level | Provisional difficulty | Slots | Boxes | Larger-box area | Winning moves | Solver states |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| 1 | Easy | 3 | 90 | 20% | 74 | 74 |
| 2 | Medium | 2 | 73 | 40% | 70 | 1,887 |
| 3 | Hard | 2 | 54 | 60% | 67 | 1,106 |

Search counts describe one solver strategy, not human difficulty. Human playtesting is still needed to calibrate the labels.

`python3 scripts/run-tests.py` passed both simulator and device stages. The physical-device report confirms 12 passed, zero failed, zero skipped, and no runtime warnings.

| Destination | Result |
| --- | --- |
| iPhone SE third-generation simulator, iOS 27.2 | All 12 UI tests passed |
| Physical iPhone SE second generation, iOS 17.1.1 | All 12 UI tests passed |
| iPhone 18 Pro simulator, iOS 27.2 | Final normal-speed gravity check passed |

The suite covers all three levels and Start Again, gravity, defeat/retry, partial-fill persistence, recharge, restoration after interrupted pouring, input locking, Reduce Motion, restart confirmation, and splash return without lost progress. Compact and larger-phone screenshots and the normal-speed gravity recording were inspected; physical-device captures confirm the iOS 17 layout. See [visual evidence](evidence/README.md).

Results are in `TestResults/20261114-095710/simulator.xcresult`, `device.xcresult`, and `TestResults/mixed-boxes-large-final.xcresult`. Project regeneration was verified reproducible, including the asset catalog and screenshot capture setting.

Tests use isolated saves. Raw result bundles remain ignored because they contain device identifiers. The shared scheme retains automatic screenshots; animation evidence is recorded separately.
