# Validation status

November 18, 2026; Xcode 27.2, iOS 17 deployment target.

- `swift test -c release`: 65 tests passed, including relative circular targeting, wraparound and fresh scans, query purity, wide-arc entry, paint conservation, partial-arc falls, alignment-aware solver/hints, generation policies, revision reports, and version-4/5 statistics migration to version 6.
- `swift run -c release LevelCheck`: all ten winning paths and six losing alternatives passed, including circular falling, partial-fill falling, and gap-pour witnesses.
- The circular-first revision reproduced all four resources byte-for-byte from the recorded baseline and seed. All five square definitions retain their exact boxes, authored order, and queues; only their campaign IDs changed. See [generation](level-generation.md).
- Eight device-selection tests passed. Project generation is idempotent, `git diff --check` passes, and the unsigned Release iOS build succeeds.

| Destination | Result |
| --- | --- |
| iPhone SE third-generation simulator, iOS 27.2 | 23/23 passed, zero failures |
| Physical iPhone SE second generation, iOS 27.2.1 | 23/23 passed, zero failures |
| iPhone 18 Pro simulator, iOS 27.2 | Both circular restoration/interruption cases passed; initial and restored layouts inspected |

Coverage includes circle → square → circle progression, final-level completion and Start Again, input locking, interrupted pours, partial-fill restoration, circular reduced motion, gravity, recharge, hints, splash return, and statistics confirmation/persistence. The deployment target remains iOS 17; these checks use the OS versions listed above.

Current gameplay evidence is maintained in the [README table](../README.md#gameplay); before/after and larger-phone captures are indexed in [visual evidence](evidence/README.md). Raw result bundles remain ignored because they contain device identifiers. The full current run is in `TestResults/20261118-214001/`; the larger-phone report is `TestResults/circular-first-large.xcresult`. The shared scheme retains screenshot capture rather than automatic video capture.

Both README videos were inspected and verified at exactly 30.000 seconds with unchanged playback speed. All four table media links resolve to existing repository files. Compact screenshots and the larger-phone initial/restored captures were inspected.
