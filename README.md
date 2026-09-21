# Share Slice

A native macOS utility that captures a selected display region and shows it in a normal window for screen sharing. The source display keeps its resolution.

Requires macOS 13 or later and Xcode 15 or later. Uses SwiftUI, AppKit, ScreenCaptureKit, and AVFoundation. No packages or third-party dependencies.

## Build and run

Open `ShareSlice.xcodeproj`, select the **ShareSlice** scheme, and run. Select your signing team in the app target if Xcode requests one. Keep the bundle identifier and signing identity stable so macOS can remember the app's permission.

From a Mac terminal:

```sh
xcodebuild -project ShareSlice.xcodeproj -scheme ShareSlice -configuration Debug -destination 'platform=macOS' build
xcodebuild -project ShareSlice.xcodeproj -scheme ShareSlice -configuration Debug -destination 'platform=macOS' test
```

## Use

1. Choose a display and Freeform, 16:9, or 4:3.
2. Click **Select Region…**. Drag outside the rectangle to draw, inside to move, or a corner to resize. Press Return to accept or Escape to cancel.
3. Click **Start Capture**. Grant Screen Recording permission when prompted. If permission is denied, use the settings button, enable Share Slice, and reopen the app if macOS requests it.
4. In Teams, choose window sharing and select **Share Slice Preview**. Keep the preview open and unminimized while sharing.
5. Click **Stop Capture** or close the preview to stop.

Change the region or aspect ratio between captures. The app remembers the last display, accepted region, and aspect ratio in UserDefaults. Display changes stop an active capture so the user can check the selection again.

## Permissions and capture

Screen Recording consent is managed by macOS TCC. This unsandboxed development app uses the hardened runtime and needs no special capture entitlement or Screen Recording usage-description key. It does not capture audio or request microphone or Accessibility access. Distribution signing and notarization are outside this MVP.

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

The initial implementation was created in a Linux workspace without Swift, Xcode, or the macOS SDK. It has not been compiled or run on macOS. The unit tests and Teams compatibility have not been verified. A successful Mac build and the checks below are required before calling this a working release.

On a Mac, run the build and tests above, then check:

- Grant, deny, and later enable Screen Recording permission.
- Draw, move, and resize each aspect ratio at display edges. Cancel a selection and confirm the previous region remains.
- Capture on Retina and non-Retina displays, including an ultrawide and displays arranged left of or below the main display. Verify the selected edges match the preview.
- Move the preview over the captured region and confirm there is no recursive image.
- Start and stop repeatedly, close the preview during capture, and unplug a captured external display.
- Relaunch and confirm the saved display, region, and aspect ratio return.
- Share **Share Slice Preview** in Teams and confirm a remote participant sees live content with the expected crop and proportions. Check CPU and memory during a longer capture.
