# Visual evidence

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
