# Paint river artwork

The approved reference is option 5 in the [original comparison](evidence/hint-design-options.png). Use its glossy turquoise liquid, detached splashes, bottom puddle, and softly shaded peach stepping stones rather than a flat route line.

The app bundles transparent [river](../App/Assets.xcassets/HintRiver.imageset/river.png) and [stone](../App/Assets.xcassets/HintStone.imageset/stone.png) sprites in the asset catalog. Step numbers and all hint instructions remain native, dynamic text; the pictures contain no instructions or numbers. The river scales behind the scrollable route, while stones retain their size beside each row.

Both sprites were generated with the built-in image generation tool using the approved comparison as an edit reference. Exact prompts and transparency settings are preserved in [artwork prompts](hint-artwork-prompts.json). These are bundled illustrations; level generation and hint computation remain entirely algorithmic and offline.
