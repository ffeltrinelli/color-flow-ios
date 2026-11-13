# Validation status

Verified on November 13, 2026, on Apple silicon / macOS 26.6.2:

- Xcode 27.2 (27B52), iOS SDK 27.2, deployment target iOS 17.0.
- Native app builds and launches in Simulator and on the physical iPhone SE second generation running iOS 17.1.1. Pairing, Developer Mode, signing, and UI Automation are configured.
- Unit and UI test runners compiled successfully for Simulator.
- `swift test`: 15 Swift Testing cases passed, including all stored winning solutions, the hard-level losing alternative, conservation after moves, snapshot recovery, and exact persistence.
- `python3 scripts/test_device_selection.py`: eight tests passed for device absence, selection, ambiguity, and blocked-device reporting.
- Offline solver found winning sequences for every bundled level:

| Level | Provisional difficulty | Moves | Visited states |
| --- | --- | ---: | ---: |
| 1 | Easy | 16 | 16 |
| 2 | Easy | 27 | 27 |
| 3 | Easy | 28 | 34 |
| 4 | Medium | 28 | 32 |
| 5 | Hard | 58 | 67 |

These counts describe one search strategy, not a calibrated difficulty score. Human playtesting remains required, particularly for medium/hard labels.

Final test results:

| Destination | Result |
| --- | --- |
| iPhone SE third-generation simulator, iOS 27.2 | 22 passed: 15 unit tests and seven end-to-end tests; zero failed or skipped |
| Physical iPhone SE second generation, iOS 17.1.1 (21B91) | All seven end-to-end tests passed; zero failed or skipped |
| Larger iPhone 17 simulator, iOS 27.2 | Restart, reduced-motion pouring, and rightmost-column pouring passed |

The seven end-to-end scenarios cover the complete five-level journey and Start Again, the hard losing branch/retry, termination during a normal pour, exact board restoration/recharge, reduced motion, restart confirmation, and right-edge pouring.

Local result bundles are `TestResults/final-compact.xcresult` and `TestResults/final-iphone.xcresult`. Selected physical-device screenshots and a separately captured simulator video were inspected for layout, clipping, stream alignment, and sequential filling; see [visual evidence](evidence/README.md). Raw result bundles and their device identifiers are ignored by Git.

The shared scheme must prefer screenshots. Automatic screen recording from Xcode 27.2 crashes the iOS 17.1.1 automation service (`testmanagerd`) before test setup. Screenshot mode is verified by the passing physical-device suite; capture animation recordings separately.

The interactive installation/pairing/signing walkthrough is complete. The app was relaunched on the phone outside the isolated UI-test session, preserving normal game progress.

Human difficulty calibration remains future playtesting work. The catalog has the requested easy/medium/hard labels, proven winning paths, and a preserved losing alternative for the hard level.
