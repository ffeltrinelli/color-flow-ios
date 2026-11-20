# Visual evidence

## Aphorism reveal

The [README gameplay table](../../README.md#gameplay) shows both boards revealing aphorisms on the iPhone SE (third generation) simulator, iOS 27.2, at 375 × 667 points. The [PR screenshots](https://github.com/ffeltrinelli/color-flow-ios/pull/11) compare the boards and victory panel and show the longest quote at the largest accessibility text size.

## Cozy Enamel boards

The pre-aphorism [square](prototype-square.png) and [circular](prototype-circular.png) captures show the original Cozy Enamel trays on the iPhone SE third-generation simulator, iOS 27.2. The matching recordings show filling, settling, and alignment beneath the fixed pointer.

## Circular-first prototype

Earlier reference images show [the divider from the previous aiming design](circular-before-relative-targeting.png), [square gameplay before the campaign reorder](square-before-circular-first.png), the [initial circular layout on iPhone 18 Pro](prototype-circular-full-large.png), and a [restored partial fill](prototype-circular-partial-large.png) on the same iOS 27.2 simulator. The [circular mid-pour still](prototype-circular-pouring.png) shows paint filling in a concentric band. The [physical iPhone SE capture](prototype-circular-device.png) shows inward settling on iOS 27.2.1.

## Stats and 50-level campaign

Inspected on iPhone SE third-generation simulator, iOS 27.2, and physical iPhone SE second generation, iOS 17.1.1 (both 375 × 667 points):

| View | Before | After |
| --- | --- | --- |
| Simulator header | [Before](stats-header-before-se.png) | [Paint badge and smaller settings button](stats-header-after-se.png) |
| Simulator settings | [Before](stats-settings-before-se.png) | [Stats entry](stats-settings-after-se.png) |
| Physical SE header | [Before](larger-settings-button-device.png) | [After](stats-header-after-device.png) |
| Physical SE settings | [Before](cartoon-settings-device.png) | [After](stats-settings-after-device.png) |

The physical SE captures show [empty statistics and Clear stats](stats-empty-device.png), a [recorded victory](stats-victory-device.png), and the [destructive confirmation](stats-clear-confirmation-device.png). Simulator counterparts show the [empty table](stats-empty-se.png), [victory](stats-victory-se.png), and [confirmation](stats-clear-confirmation-se.png). Histogram, gear, eraser, and close icons are visible; the table, button, and confirmation fit the compact layout.

Historical validation: 51 release core tests passed. The runner currently contains eight device-selection tests; see the current validation document. `LevelCheck` verified all 50 winning paths and 33 losing alternatives. The original nine definitions, paths, and metrics were preserved; 27 original version-4 save checkpoints restored exactly. Both generation modes reproduced their recorded data, including a byte-for-byte match of all four expanded resources.

The final routine suite passed 17 UI tests on each SE, covering clear confirmation/cancellation, persistent statistics, unchanged boards, restoration, and animation behavior. A separate full journey passed all 50 levels and Start Again on iPhone 18 Pro simulator, iOS 27.2; its [level 50 capture](stats-level-50-large.png) was inspected. Clear stats was subsequently verified in the updated routine suites. Raw result bundles remain ignored; use hosted repository URLs for these selected images when preparing a PR.

## Paint river hints and cartoon controls

Inspected on the physical iPhone SE second generation, iOS 17.1.1 (375 × 667 points):

- [Larger settings button](larger-settings-button-device.png) and [settings menu](cartoon-settings-device.png), with consistent icon-and-text controls.
- [Loading-wheel regression](hint-loading-device.png), showing the empty startup state without a false timeout.
- [Paint river hints](paint-river-hints-device.png) and [scrolled fifth step](paint-river-hints-scrolled-device.png), with exact queue/bucket targets and readable quantities.
- [Blocked bucket lock](blocked-lock-device.png), positioned above the bucket without covering its paint count.
- Centered [level completion](level-complete-device.png), [game completion](game-complete-device.png), and [defeat](defeat-device.png) overlays from the passing routine suite.

The [larger-phone hint capture](paint-river-hints-large.png) was also inspected on iPhone 18 Pro simulator, iOS 27.2.

The final river and stone sprites follow [option 5 of the original comparison](hint-design-options.png); see [artwork notes](../hint-artwork.md). Final focused checks passed on the physical SE and compact simulator (three tests each), plus the larger simulator hint check.

Earlier [SE board](mixed-boxes-board-device.png) provides the before reference for the header and bucket captions.

## Mixed-size boxes and splash

Inspected on iPhone SE third-generation Simulator (375 × 667 points) and iPhone 18 Pro Simulator, both iOS 27.2:

- [SE board](mixed-boxes-board-se.png), [half-filled domino](mixed-boxes-partial-se.png), and [SE splash](mixed-boxes-splash-se.png).
- [Revised Cozy Pour splash](mixed-boxes-splash-large.png), with peach breathing room and the cartoon title.
- [Initial mixed-size board](mixed-boxes-board-large.png), including 3 × 3 containers.
- [Settled board with retained partial fill](mixed-boxes-settled-large.png).
- [Normal-speed filling and gravity recording](mixed-boxes-pour-gravity.mp4), showing liquid spreading across box interiors and the stream hidden while boxes fall.

The physical iPhone SE second generation, iOS 17.1.1, was also inspected: [mixed-size board](mixed-boxes-board-device.png), [half-filled domino](mixed-boxes-partial-device.png), and [revised splash](mixed-boxes-splash-device.png).

| Before/after comparison | Before: 1 × 1 board | After: mixed-size board |
| --- | --- | --- |
| SE simulator, iOS 27.2 | [Before](top-down-after-se.png) | [After](mixed-boxes-board-se.png) |
| Physical SE, iOS 17.1.1 | [Before](top-down-after-device.png) | [After](mixed-boxes-board-device.png) |
| Larger simulator, iOS 27.2; before iPhone 17, after iPhone 18 Pro | [Before](top-down-after-large.png) | [After](mixed-boxes-board-large.png) |

Earlier 1 × 1 layouts below provide before references. Simulator/device test bundles are ignored and should not be uploaded wholesale. For a UI PR, embed selected images through repository URLs or accessible uploaded attachments and identify the device/OS; include the recording for pouring changes.

## Earlier top-down clearing evidence

Inspected before/after captures for the top-down clearing update:

| Device | OS | Before | After |
| --- | --- | --- | --- |
| iPhone SE third-generation simulator, 375 × 667 points | iOS 27.2 | [Six-column board](top-down-before-se.png) | [10 × 10 board](top-down-after-se.png) |
| iPhone 17 simulator | iOS 27.2 | [Original layout](top-down-before-large.png) | [Expanded board](top-down-after-large.png) |
| Physical iPhone SE second generation | iOS 17.1.1 | [Original layout](iphone-se.png) | [Expanded board](top-down-after-device.png) |

[Updated pour recording](top-down-pour.mp4) shows nine blocks clearing automatically across six columns, including the rightmost column. The final timing is about 4.8 seconds of pouring, with visible fills and pauses between columns. Frame-by-frame inspection confirmed that the stream disappears at column boundaries and stays absent during travel. The [travel still](top-down-pour.png) shows the bucket moving with no residual stream.

Compact and larger-phone captures were checked for clipping, four-point board margins, visible queue previews, and bucket quantities. The physical-device capture also verifies the iOS 17 layout. Earlier foundation captures remain in this directory as references.

For a pull request, embed selected images using repository URLs or uploaded attachments, with device/OS and before/after comparisons. Local file links are not shareable PR evidence. Raw test results contain device identifiers and remain ignored.
