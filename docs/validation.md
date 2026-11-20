# Validation status

Cozy Enamel refresh, November 20, 2026. Xcode 27.2, iOS 17 deployment target.

- `swift test -c release` passed all 65 tests.
- `swift run -c release LevelCheck` replayed all ten winning paths and six losing alternatives.
- All eight device-selection tests passed. Project generation was reproducible, the unsigned Release iOS build succeeded, and `git diff --check` passed.

| Destination | Result |
| --- | --- |
| iPhone SE third-generation simulator, iOS 27.2 | 23/23 user interface tests passed. Inspected dense boards, partial fills, and both pours at 375 × 667 points. |
| Physical iPhone SE second generation, iOS 27.2.1 | 23/23 user interface tests passed. |
| iPhone 18 Pro simulator, iOS 27.2 | Inspected before-and-after layouts for both boards. |

The UI suite covers compact layout and accessibility, circular alignment, partial fills, sequential pouring, falling, Reduce Motion, and restoration after interruption. The [gameplay table](../README.md#gameplay) uses inspected screenshots and 30-second normal-speed recordings for both board kinds. Earlier captures are indexed in [visual evidence](evidence/README.md). Raw test bundles remain in the ignored `TestResults/` directory.
