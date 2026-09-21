# Share Slice

A native macOS utility that captures a selected display region and shows it in a normal window for screen sharing. The source display keeps its resolution.

Requires macOS 13 or later and Xcode 15 or later. The test target requires macOS 14 or later to match the XCTest libraries bundled with Xcode 27. Uses SwiftUI, AppKit, ScreenCaptureKit, and AVFoundation. No packages or third-party dependencies.

## Build and run

Open `ShareSlice.xcodeproj`, select the **ShareSlice** scheme, and run. Select your signing team in the app target if Xcode requests one. Keep the bundle identifier and signing identity stable so macOS can remember the app's permission.

From a Mac terminal:

```sh
./scripts/build.sh
xcodebuild -project ShareSlice.xcodeproj -scheme ShareSlice -configuration Debug -destination 'platform=macOS' test
```

The build script prints the app path under `.build/local`. It uses ad hoc signing
and doesn't require an Apple Developer account. Run it from any directory.

## Release packages

```sh
./scripts/release.sh 0.1.0
```

This runs the tests on the host Mac, builds a Release app for Apple Silicon and
Intel, and writes `dist/Share-Slice-0.1.0.zip`. The version must be three numbers
separated by dots. It sets both app version fields without changing the Xcode
project. Existing ZIPs aren't overwritten. Build products and logs stay under
`.build/releases`; `.build` and `dist` are ignored by Git.

Without signing credentials, the ZIP is for local testing. For public downloads,
install your Developer ID Application certificate and private key in Keychain,
then save notarization credentials using the interactive prompt:

```sh
xcrun notarytool store-credentials ShareSlice
export DEVELOPER_ID='Developer ID Application: Your Name (TEAMID)'
export NOTARY_PROFILE=ShareSlice
./scripts/release.sh 0.1.0
```

Set both variables to sign and notarize the app. The script checks Apple's result,
staples the ticket, and checks Gatekeeper before packaging. See
[Apple's notarization workflow](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow)
for credential setup. Move any earlier local ZIP out of `dist` before rebuilding
the same version with signing enabled.

To upload a draft, install and authenticate GitHub CLI with `gh auth login`,
commit the release source, and push a version tag at that commit:

```sh
git tag v0.1.0
git push origin v0.1.0
./scripts/release.sh 0.1.0 --draft
```

Keep the signing variables set. `--draft` requires a clean checkout and the tag
at HEAD on `origin`. It builds the package and uploads it with generated release
notes using [GitHub CLI](https://cli.github.com/manual/gh_release_create).
Review and publish the draft on GitHub. The script doesn't publish automatically.
If you already built the signed ZIP, upload it directly instead of rebuilding:

```sh
gh release create v0.1.0 dist/Share-Slice-0.1.0.zip --verify-tag --draft --generate-notes
```

## Use

1. Choose a display and Freeform, 16:9, or 4:3.
2. Click **Select Region…**. Drag outside the rectangle to draw, inside to move, or a corner to resize. Press Return to accept or Escape to cancel.
3. Click **Start Capture**. Grant Screen Recording permission when prompted. If permission is denied, use the settings button, enable Share Slice, and reopen the app if macOS requests it.
4. In Teams, choose window sharing and select **Share Slice Preview**. Keep the preview open and unminimized while sharing.
5. Click **Stop Capture** or close the preview to stop.

Change the region or aspect ratio between captures. The app remembers the last display, accepted region, and aspect ratio in UserDefaults. Display changes stop an active capture so the user can check the selection again.

In the selection overlay, diagonal arrows mark corner resize targets. An open hand
marks the interior and remaining border, where dragging moves the region; the hand
closes during the drag. A crosshair outside the region indicates drawing a new one.

## Permissions and capture

Screen Recording consent is managed by macOS TCC. This unsandboxed development app enables the hardened runtime in its build settings and needs no special capture entitlement or Screen Recording usage-description key. Xcode disables the hardened runtime when signing ad hoc with "Sign to Run Locally", as in the validation build below. It does not capture audio or request microphone or Accessibility access. The release script enables the hardened runtime when signing with Developer ID.

The preview is a regular titled, resizable NSWindow. ScreenCaptureKit excludes the Share Slice application from its own feed, including its controls and preview, without marking the preview private to other capture apps. Teams needs its own screen-sharing permissions.

Regions use display-local logical points measured from the top left. The overlay uses a flipped AppKit view with the same coordinates as the capture source rectangle. Output dimensions apply the selected screen's backing scale. Capture runs at up to 30 fps with a three-frame ScreenCaptureKit queue. Frames go directly to an AVSampleBufferDisplayLayer; the main-thread handoff retains only the latest pending frame.

## Files

- `ShareSliceApp.swift`: app entry point and control window.
- `AppModel.swift`: display selection, permissions, persistence, and capture lifecycle.
- `RegionGeometry.swift`: bounds, aspect ratios, and coordinate calculations.
- `SelectionOverlay.swift`: drawing, moving, and resizing the region.
- `CaptureSession.swift`: ScreenCaptureKit stream and frame delivery.
- `PreviewWindow.swift`: shareable preview window and video layer.
- `ShareSliceTests/RegionGeometryTests.swift`: geometry tests.

## Validation status

Checked on September 21, 2026, starting from commit `3aec281`, with Xcode 27.0, build 27A266a, on macOS 26.6.2, build 25G83.

- Debug app build passed for arm64 and x86_64. No Swift compiler errors or warnings appeared.
- All 8 geometry tests passed on arm64, including coordinate conversion, Retina output sizing, bounds, and aspect ratios. These are calculation tests, not proof of live screen cropping.
- Fixed test linker warnings by setting the test target's minimum macOS version to 14. The app still targets macOS 13.
- Xcode still reports `Metadata extraction skipped, no AppIntents.framework dependency found`. This comes from its metadata tool, not the Swift compiler. The app has no App Intents.
- The app launched and listed the built-in Retina display at 1728 × 1117 logical points. The selection overlay opened. Escape cancelled it and returned to the controls without accepting a region.
- Automated drawing could not run because the UI tool returned `windowNotFoundAtPosition` for the borderless overlay. Tom subsequently reported that selection seemed to work; individual move and resize checks remain unconfirmed.
- Increased the selection border to 4 points in cyan with a black outline, enlarged corner handles and their drag targets, and added a 6-point margin for moving from the border. The updated app builds and all 8 geometry tests pass. The new appearance and drag targets still need a manual check.
- The first test attempt was blocked by sandbox access to Apple's test service. The rerun outside the sandbox passed, as did the rerun after the test-target fix.

Local logs are `/private/tmp/share-slice-build.log` and `/private/tmp/share-slice-test.log`. Build products and XCTest results are under `/private/tmp/share-slice-derived`. These temporary files aren't committed.

Runtime validation is incomplete. The following checks remain pending:

- Grant, deny, and later enable Screen Recording permission.
- Draw, move, and resize each aspect ratio at display edges. Cancel a selection and confirm the previous region remains.
- Capture on Retina and non-Retina displays, including an ultrawide and displays arranged left of or below the main display. Verify the selected edges match the preview.
- Move the preview over the captured region and confirm there is no recursive image.
- Start and stop repeatedly, close the preview during capture, and unplug a captured external display.
- Relaunch and confirm the saved display, region, and aspect ratio return.
- Share **Share Slice Preview** in Teams and confirm a remote participant sees live content with the expected crop and proportions. Check CPU and memory during a longer capture.
