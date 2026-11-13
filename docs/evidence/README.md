# Visual evidence

Inspected before/after captures for the top-down clearing update:

| Device | OS | Before | After |
| --- | --- | --- | --- |
| iPhone SE third-generation simulator, 375 × 667 points | iOS 27.2 | [Six-column board](top-down-before-se.png) | [10 × 10 board](top-down-after-se.png) |
| iPhone 17 simulator | iOS 27.2 | [Original layout](top-down-before-large.png) | [Expanded board](top-down-after-large.png) |
| Physical iPhone SE second generation | iOS 17.1.1 | [Original layout](iphone-se.png) | [Expanded board](top-down-after-device.png) |

[Updated pour recording](top-down-pour.mp4) shows nine blocks clearing automatically across six columns, including the rightmost column. The final timing is about 4.8 seconds of pouring, with visible fills and pauses between columns. Frame-by-frame inspection confirmed that the stream disappears at column boundaries and stays absent during travel. The [travel still](top-down-pour.png) shows the bucket moving with no residual stream.

Compact and larger-phone captures were checked for clipping, four-point board margins, visible queue previews, and bucket quantities. The physical-device capture also verifies the iOS 17 layout. Earlier foundation captures remain in this directory as references.

For a pull request, embed selected images using repository URLs or uploaded attachments, with device/OS and before/after comparisons. Local file links are not shareable PR evidence. Raw test results contain device identifiers and remain ignored.
