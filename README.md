# Share Slice

A native macOS utility that captures a selected display region and shows it in a normal window for screen sharing. The source display keeps its resolution.

Requires macOS 13 or later. Building from source requires Xcode 15 or later. The test target requires macOS 14 or later to match the XCTest libraries bundled with Xcode 27. Uses SwiftUI, AppKit, ScreenCaptureKit, and AVFoundation. No packages or third-party dependencies.

## Download and install

Download the app ZIP from [Releases](https://github.com/tadamo/share-slice/releases),
unzip it, and drag **Share Slice.app** to **Applications**. Xcode isn't needed.
The ZIP supports Apple Silicon and Intel Macs.

GitHub Actions builds use ad hoc signing and aren't notarized by Apple. If macOS
blocks the app, try opening it, then go to **System Settings > Privacy & Security >
Open Anyway**. Only allow it if you trust the download. See
[Apple's instructions](https://support.apple.com/en-us/102445).
Grant Screen Recording access when starting capture.

## Build and run

Open `ShareSlice.xcodeproj`, select the **ShareSlice** scheme, and run. Select your signing team in the app target if Xcode requests one. Keep the bundle identifier and signing identity stable so macOS can remember the app's permission.

From a Mac terminal:

```sh
./scripts/build.sh
xcodebuild -project ShareSlice.xcodeproj -scheme ShareSlice -configuration Debug -destination 'platform=macOS' test
```

The build script prints the app path under `.build/local`. It uses ad hoc signing
and doesn't require an Apple Developer account. Run it from any directory.
It quits Share Slice before building and resets only its Screen Recording
permission after a successful build to clear stale consent from the old signature.
Reopen the app and grant access when starting capture. This applies to the build
script, not builds run directly in Xcode.

## GitHub releases

The [release workflow](.github/workflows/release.yml) runs when you push a tag such
as `v0.1.1`. It tests the app, builds both Mac architectures, and publishes a release
with the app ZIP and installation steps. It uses GitHub's built-in token; no extra
secrets or Apple Developer account are needed. Actions must be enabled in the repo.

Commit and push the workflow and app changes before creating a release tag:

```sh
git tag v0.1.1
git push origin v0.1.1
```

Tags must use `vMAJOR.MINOR.PATCH`. Pushing a matching tag publishes automatically
after the build and tests pass. Reruns won't overwrite an existing release. If a
run fails before creating a release, rerun it from Actions. If a release already
exists, inspect it and use a new version for any correction.

These automated downloads aren't Developer ID signed or notarized. For a signed
release, use the local process below with a version tag outside the `v*` pattern,
such as `signed-0.1.1`, and upload the ZIP with `gh release create`. Don't push a
`v*` tag for that release, since it triggers the ad hoc build.

## Release packages

```sh
./scripts/release.sh 0.1.0
```

This runs the tests on the host Mac, builds a Release app for Apple Silicon and
Intel, and writes `dist/Share-Slice-0.1.0.zip`. The version must be three numbers
separated by dots. It sets both app version fields without changing the Xcode
project. Existing ZIPs aren't overwritten. Build products and logs stay under
`.build/releases`; `.build` and `dist` are ignored by Git.

Without signing credentials, macOS may block the ZIP's app until the user allows it
in Privacy & Security. To sign and notarize a download, install your Developer ID
Application certificate and private key in Keychain,
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

To upload a signed draft without triggering the automated ad hoc release, build
with the signing variables set, commit and push the source, then use a separate tag:

```sh
git tag signed-0.1.1
git push origin signed-0.1.1
gh release create signed-0.1.1 dist/Share-Slice-0.1.1.zip --verify-tag --draft --generate-notes
```

Review and publish the draft on GitHub. GitHub CLI requires `gh auth login` first.
The release script's older `--draft` option uses `v*` tags, so don't use it while
the automated release workflow is enabled.

## Use

1. Choose a display and Freeform, 16:9, or 4:3. The saved region appears on launch, or a centered default appears if none is saved.
2. Drag the Move handle to reposition the region or a corner to resize. The interior and border pass clicks through to your apps.
3. Click **Start Capture**. Grant Screen Recording permission when prompted. If permission is denied, use the settings button, enable Share Slice, and reopen the app if macOS requests it.
4. In Teams, choose window sharing and select **Meeting Share Window**. Keep the sharing window open and unminimized while sharing.
5. Adjust the region or aspect ratio during capture to update the sharing window. The border turns red and the move handle says LIVE while capturing.
6. Click **Stop Capture** or close the sharing window to stop. The region stays visible and adjustable.

The app remembers the last display, region, and aspect ratio in UserDefaults. Display changes stop an active capture so you can check the region again. Switch displays between captures. Handles briefly pause during capture startup and shutdown.

## Permissions and capture

Screen Recording consent is managed by macOS TCC. This unsandboxed development app enables the hardened runtime in its build settings and needs no special capture entitlement or Screen Recording usage-description key. Xcode disables the hardened runtime when signing ad hoc with "Sign to Run Locally", as in the validation build below. It does not capture audio or request microphone or Accessibility access. The release script enables the hardened runtime when signing with Developer ID.

The sharing window is a regular titled, resizable NSWindow. ScreenCaptureKit excludes the Share Slice application from its own feed, including its controls and sharing window, without marking the sharing window private to other capture apps. Teams needs its own screen-sharing permissions.

Regions use display-local logical points measured from the top left. The outline converts these coordinates to AppKit screen coordinates; handle drags convert screen deltas back to display-local points. Output dimensions apply the selected screen's backing scale. Capture runs at up to 30 fps with a three-frame ScreenCaptureKit queue. Frames go directly to an AVSampleBufferDisplayLayer; the main-thread handoff retains only the latest pending frame.

## Files

- `ShareSliceApp.swift`: app entry point and control window.
- `AppModel.swift`: display selection, permissions, persistence, and capture lifecycle.
- `RegionGeometry.swift`: bounds, aspect ratios, and coordinate calculations.
- `SelectionOverlay.swift`: persistent outline, move handle, and corner resize handles.
- `CaptureSession.swift`: ScreenCaptureKit stream and frame delivery.
- `PreviewWindow.swift`: sharing window and video layer.
- `ShareSliceTests/RegionGeometryTests.swift`: geometry tests.

## Validation status

The always-adjustable region change was checked on September 21, 2026:

- The arm64 Debug build passed and all 10 geometry tests passed. No Swift compiler warnings were introduced. The existing App Intents metadata warning remains.
- The local app launched with the saved region dimensions and the new controls. The help text fits, and Select Region is gone.
- Starting capture showed the missing Screen Recording permission error. Live capture and live region updates could not be verified on this build.
- Handle dragging, click-through behavior, display-edge behavior, and the live border still need a manual check. The UI tool exposed only the control window.
- The built app is at `.build/local/Build/Products/Debug/Share Slice.app`. Build and test logs are `/private/tmp/share-slice-build.log` and `/private/tmp/share-slice-test.log`.

### Earlier validation

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
- Move and resize each aspect ratio at display edges, both idle and during capture. Confirm interior clicks reach the underlying app.
- Capture on Retina and non-Retina displays, including an ultrawide and displays arranged left of or below the main display. Verify the selected edges match the sharing window.
- Move the sharing window over the captured region and confirm there is no recursive image.
- Start and stop repeatedly, close the sharing window during capture, and unplug a captured external display.
- Relaunch and confirm the saved display, region, and aspect ratio return.
- Share **Meeting Share Window** in Teams and confirm a remote participant sees live content with the expected crop and proportions. Check CPU and memory during a longer capture.
