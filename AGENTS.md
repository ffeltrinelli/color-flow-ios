# Development guidance

- Use the `clean-code` skill for code changes and reviews. Keep engine rules independent of SwiftUI, persistence, and animation.
- Animate the engine-provided pour result; do not duplicate targeting in the UI. Commit and save the complete move before presentation begins.
- Keep UI, accessibility labels, data, identifiers, code, and technical documentation in English.
- See [README](README.md) for setup/testing and [native design](docs/game-design.md) for behavior. Maintain iOS 17 compatibility and the iPhone SE 375 × 667-point layout.
- Levels are authored JSON, never randomized at runtime. Validate with `swift run LevelCheck`; preserve and test winning sequences after edits. Inconclusive searches are not proof of solvability or impossibility.
- Run `swift test` for core changes. Run `python3 scripts/test_device_selection.py` for test-runner changes. For app/UI changes, run `python3 scripts/run-tests.py` (simulator plus the configured SE when connected); report unavailable/blocked device runs accurately.
- Help users install Xcode and connect the iPhone interactively, one verified step at a time. README instructions alone do not complete setup. Do not start duplicate runtime downloads while the user is installing through Xcode; wait for confirmation. Never request passwords or verification codes in chat.
- Keep the shared test scheme’s preferred screen capture format set to screenshots. Xcode 27.2 automatic video recording crashes `testmanagerd` on iOS 17.1.1; capture animation evidence separately.
- Put accessibility identifiers on leaf controls. For queryable SwiftUI groups, use `accessibilityElement(children: .contain)`; ancestor identifiers can replace descendant identifiers.
- Keep Canvas-backed button labels accessible. Apply `accessibilityHidden(true)` only to decorative uses; hiding the label artwork makes buttons report as unhittable on iOS 17.1.1.
- After adding/removing app or test Swift files, regenerate target membership with `python3 scripts/create-project.py` and review the project diff. Personal signing belongs in ignored `Config/Local.xcconfig`.
- Every PR affecting visible UI must embed relevant inspected screenshots, identify device/OS, and include before/after views when changing an existing screen. Pour-animation changes also require a short recording. Use uploaded images or accessible artifacts, not local file links. State capture/upload blockers explicitly; never claim missing evidence exists.
- Review this guidance before completing a PR; update only durable, verified conventions. Keep product explanations, validation evidence, and outstanding work in docs rather than here.
