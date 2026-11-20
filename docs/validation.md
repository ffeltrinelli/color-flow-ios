# Validation status

Offline aphorisms and the new campaign, November 20, 2026. Xcode 27.2, iOS 17 deployment target.

- `swift test -c release` passed all 68 core tests. `swift run -c release LevelCheck` replayed all 50 winning paths and 30 losing alternatives and verified the circular fall and gap-pour requirements.
- Seed `2026112002` reproduced all four campaign files byte for byte. All 50 definitions are unique and differ from the ten prototype levels.
- All eight device-selection tests passed. Project generation was reproducible and the unsigned Release iOS build included the complete aphorism catalog.

| Destination | Result |
| --- | --- |
| iPhone SE third-generation simulator, iOS 27.2 | 23 of 23 UI tests passed. Inspected both boards from level start through reveal and victory at 375 × 667 points. The longest quote scrolls at the largest accessibility text size while Start Again stays visible. |
| Physical iPhone SE second generation, iOS 27.2.1 | 23 of 23 UI tests passed. |
| iPhone 18 Pro simulator, iOS 27.2 | Inspected both boards during the reveal and the victory panel. |

The [gameplay table](../README.md#gameplay) shows inspected screenshots and 30-second recordings at normal speed. [PR #11](https://github.com/ffeltrinelli/color-flow-ios/pull/11) includes before-and-after captures. Earlier captures are indexed in [visual evidence](evidence/README.md). Raw test bundles remain in the ignored `TestResults/` directory.
