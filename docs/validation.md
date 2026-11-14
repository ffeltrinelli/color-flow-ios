# Validation status

November 14, 2026; Xcode 27.2, iOS 17 deployment target.

- `swift test -c release`: 51 tests passed in approximately 3.4 seconds after building. Fixed fixtures cover engine/search rules, hints, generation, attempt counting, paused timing, legacy saves, clear statistics, and invalid-board recovery without depending on the published campaign.
- `swift run -c release LevelCheck`: all 50 stored winning paths and 33 losing alternatives replay correctly; generation batches, metrics, IDs, and duplicate checks pass.
- The original nine definitions, winning/losing paths, and metrics are unchanged. Twenty-seven original version-4 save checkpoints, including completed level 9, restored exactly against the expanded catalog.
- Seeds `20261114` and `2026111401` reproduce the original and appended batches. All four regenerated 50-level resource files match byte-for-byte. See [generation](level-generation.md) for reproduction commands and difficulty limitations.
- `python3 scripts/test_device_selection.py`: all 10 runner checks passed.

| Destination | Result |
| --- | --- |
| iPhone SE third-generation simulator, iOS 27.2 | 17/17 routine UI tests passed |
| Physical iPhone SE second generation, iOS 17.1.1 | 17/17 routine UI tests passed |
| iPhone 18 Pro simulator, iOS 27.2 | Full 50-level journey and Start Again passed in approximately 34 minutes |

The routine suite verifies representative layouts, progression/completion, saved boards, hints, animation locking, Reduce Motion, splash return, persistent statistics, and Clear stats confirmation/cancellation. Clearing statistics preserves the current board through relaunch. Icons and compact overlay layouts were inspected on both SEs; [visual evidence](evidence/README.md) includes before/after captures. The later invalid-board recovery adjustment passed its core regression and a final signed device build.

Routine reports are in `TestResults/20261114-170813/`; the full journey is in `TestResults/stats-full-campaign.xcresult`. The full journey exercised the expanded catalog before the Clear stats addition; the updated routine suites cover that control. Raw reports remain ignored because they contain device identifiers. Project regeneration retains screenshot recording.
