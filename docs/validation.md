# Validation status

November 17, 2026; Xcode 27.2, iOS 17 deployment target.

- `swift test -c release`: 57 tests passed. Coverage includes circular geometry and area-based filling, counterclockwise alignment, reproducible generation, version-4 statistics migration, version-5 state/orientation restoration, shared engine/search rules, and hints.
- `swift run -c release LevelCheck`: all ten winning paths and six losing alternatives passed, including the prototype configuration and circular fall/gap/partial-fill witnesses.
- Seed `2026111701` reproduced all four bundled resources byte-for-byte. See [generation](level-generation.md).
- `python3 scripts/test_device_selection.py`: eight tests passed. Xcode project regeneration is consistent, and the unsigned Release iOS build passed.

| Destination | Result |
| --- | --- |
| iPhone SE third-generation simulator, iOS 27.2 | All 23 current UI cases passed across the full run and focused rerun |
| Physical iPhone SE second generation, iOS 27.2.1 | Full suite: 23/23 passed, none skipped |
| iPhone 18 Pro simulator, iOS 27.2 | Both normal-speed interruption/restoration cases passed; full and partial circular layouts inspected |

The initial compact run passed 21 of its 22 compiled cases; its interruption test assumed queue zero remained present after preparation. The corrected test checks remaining queues and passed on rerun, alongside the newly added circular interruption case. Consequently, the original `run-tests.py` invocation exits nonzero for that superseded simulator assertion even though its device suite passes. There are no unresolved failures among the current UI cases.

Coverage includes square → circle → square progression, final-level completion and Start Again, input locking, interrupted pours, partial-fill restoration, circular reduced motion, gravity, recharge, hints, splash return, and statistics confirmation/persistence. The deployment target remains iOS 17; this validation used the OS versions listed above rather than an iOS 17 runtime.

Both [README gameplay videos](../README.md#gameplay) were inspected and verified as exactly 30.000 seconds at normal playback speed. Their screenshots and all four repository-relative table links were checked. The circular recording shows centered pouring, counterclockwise rotation, clearing, and inward settling. Compact, larger-phone, and physical-device screenshots confirm concentric paint and the persistent white divider; see [visual evidence](evidence/README.md).

Raw reports remain ignored because they contain device identifiers. The full runs are in `TestResults/20261117-224334/`; corrected focused reports are `prototype-interruption-compact-fixed.xcresult` and `prototype-interruption-large-fixed.xcresult`. Screenshot recording remains enabled in the shared scheme.
