# Color Flow

An offline iPhone puzzle game for iOS 17+. Empty a 10 × 10 board of mixed-size boxes while managing active buckets and four reserve queues. Paint spreads across each box and remains until it fills; full boxes disappear and unsupported boxes fall. Tap a bucket to pour automatically into exposed matching boxes from left to right. The fixed campaign has 50 levels: the original nine followed by 41 puzzles in a seeded, shuffled difficulty order. Your exact board is saved after every move. Version-4 saves keep their current level and exact board when updating; older save versions start at level one.

The primary compact-device target is iPhone SE (second generation), including iOS 17.1.1. See [game design](docs/game-design.md) and [validation status](docs/validation.md).

## First setup

Full Xcode is required; Command Line Tools alone do not include the iOS software development kit (SDK) and Simulator. Installation and device connection should be completed interactively with the agent, one verified step at a time.

1. Install stable Xcode compatible with your macOS and iOS 17 device debugging. Open it, review Apple's license, and finish required-component installation.
2. In Xcode → Settings → Components, install an iOS Simulator runtime. Select Xcode → Settings → Locations → Command Line Tools if the active toolchain is incorrect. Verify with `xcodebuild -version` and `xcodebuild -checkFirstLaunchStatus`.
3. Open `ColorFlow.xcodeproj`. In Window → Devices and Simulators (Device Hub in newer Xcode), create an iPhone SE simulator with an available compatible runtime. An SE third-generation simulator has the same 375 × 667-point layout. If the runtime no longer supports an SE simulator, install an older runtime supported by Xcode. Do not update the physical SE to accommodate a simulator runtime.
4. Select the ColorFlow scheme and simulator, then Run. No development team is needed for Simulator.

If Xcode fails at launch with `_XPCTypeBool` in an old `/Library/Developer/PrivateFrameworks/CoreDevice.framework`, inspect the framework version and crash output first. A stale shared developer framework installation can survive an Xcode reinstall. Move the affected directory to a uniquely named backup with administrator authorization, reopen Xcode, and let first-launch setup reinstall components. Do not delete system frameworks or apply this workaround to unrelated launch errors.

## Connect your iPhone

1. Connect with a data-capable Lightning cable, unlock the phone, and accept **Trust This Computer** on the phone.
2. Select the phone in Xcode's device manager and wait for pairing to complete.
3. Enable **Settings → Privacy & Security → Developer Mode** on the phone; restart and confirm. The setting may appear only after pairing begins.
4. In Settings → Developer on the phone, enable **Enable UI Automation** and accept any approval prompt. For longer test sessions, temporarily set Settings → Display & Brightness → Auto-Lock to Never (turn off Low Power Mode if that control is disabled).
5. Add your Apple Account in Xcode → Settings → Apple Accounts. A free Personal Team supports basic local device development; its provisioning profiles expire and may need renewal.
6. Copy `Config/Local.xcconfig.example` to `Config/Local.xcconfig`. Set your development team identifier and a unique bundle prefix. This file is ignored by Git. Let Xcode manage signing automatically for the app and test targets. Do not share passwords, verification codes, signing certificates, or device identifiers in pull requests.
7. Select your unlocked phone as the run destination and run the app. If iOS asks to trust the developer under Settings → General → VPN & Device Management, complete that step.
8. Run the simulator-and-device test command below. Keep the phone connected and unlocked during tests. The agent must inspect the resulting device test report before declaring setup verified.

## Tests

```sh
swift test -c release
swift run LevelCheck
python3 scripts/test_device_selection.py
python3 scripts/run-tests.py
```

Release mode keeps the algorithmic generation/search tests fast.

The final command runs the routine simulator UI suite and also runs the same UI suite on an available iPhone SE second generation. It reports an absent phone as skipped; trust, pairing, lock, signing, and execution failures are blockers. Tests use separate game-save files and never reset normal play progress.

A unique device identifier (UDID) selects a simulator or phone. Select specific destinations when necessary:

```sh
xcrun simctl list devices available
python3 scripts/run-tests.py --simulator SIMULATOR_UDID --device DEVICE_UDID
```

`SIMULATOR_UDID` and `DEVICE_UDID` environment variables provide the same overrides. Results are written to timestamped directories under `TestResults/`, with separate simulator/device `.xcresult` bundles. Open them in Xcode to inspect screenshots and failures. Do not commit raw results containing device identifiers.

The shared scheme uses automatic screenshots: Xcode 27.2 automatic video recording crashes the automation service on iOS 17.1.1. Preserve this setting when changing schemes; capture animation recordings separately.

Unit tests use Swift Testing; user interface (UI) tests use XCTest and operate the actual app through accessibility controls. The routine suite covers representative easy/medium/hard layouts, one level transition and campaign completion, rectangular boxes, persistent partial fills, gravity, recharge, read-only board layout, restoration, restart, defeat/retry, animation interaction locking, reduced motion, and the splash on launch and background return. Stats in Settings shows win percentage and average winning time for each difficulty. Core tests use fixed engine/search fixtures. `LevelCheck` separately audits every published winning path, losing alternative, and generation report. Use `python3 scripts/run-tests.py --full-campaign` for the optional, slower 50-level UI journey before release.

Publish level replacements as a complete generated output set, then run `swift run -c release LevelCheck`. Its default audit replays stored proofs; `--solve` additionally searches for fresh paths, and `--write-solutions` recomputes the winning-path file. Generation metadata must remain consistent. Levels are generated offline; the app uses the same algorithmic solver for on-demand hints. See [level generation](docs/level-generation.md) for randomized generation, reproducible seeds, difficulty profiles, and safe campaign replacement. `python3 scripts/create-project.py` reproducibly updates Xcode target membership if app/test Swift files are added or removed.

## Visual review and pull requests

For visible changes, capture and inspect relevant screenshots on the compact layout and a larger phone. Embed accessible images in the pull request (PR) description; include before/after images when changing existing UI. State device and OS. For pouring changes, include a short recording to show alignment, continuous flow, sequential filling/removal, column switching, and responsiveness. Keep images limited to game content.

Simulator capture examples (replace `booted` with an explicit simulator UDID when multiple simulators are running):

```sh
xcrun simctl io booted screenshot /tmp/color-flow.png
xcrun simctl io booted recordVideo /tmp/color-flow.mov
```

Stop recording with Control-C. UI tests also preserve selected screenshots as test-report attachments. Upload selected evidence to the PR or an accessible artifact location; local filesystem links are not shareable PR evidence. Report capture/upload blockers honestly.
