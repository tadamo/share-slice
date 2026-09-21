# Share Slice

Share Slice is a small native macOS utility that lets a user select part of a display and expose that region as a normal window for screen sharing apps such as Microsoft Teams.

## Goals

- Native macOS app
- Small and easy to understand
- Low CPU and memory use
- Smooth live screen capture
- Good support for ultrawide displays
- Minimal setup for the user

## Tech

- Swift
- SwiftUI
- ScreenCaptureKit
- Xcode
- macOS only

Avoid third-party dependencies unless they provide clear value that cannot be reasonably implemented with Apple frameworks.

## Development principles

- Keep the design simple.
- Prefer the smallest working implementation.
- Avoid premature abstractions.
- Do not introduce frameworks, packages, or architectural layers without a clear need.
- Prefer Apple APIs and standard Swift patterns.
- Keep files reasonably small and focused.
- Use clear names instead of excessive comments.
- Do not add features outside the current task.

## MVP

The first version should support:

- Select a display
- Draw/select a rectangular capture region
- Resize and move the region
- Optional fixed aspect ratio
- Capture that region with ScreenCaptureKit
- Show it in a separate preview window
- Start and stop capture
- Remember the last region and basic preferences
- Handle Screen Recording permission

The preview window is the primary output. Users will select this window when sharing content in Microsoft Teams.

## UI

Keep the UI minimal.

Prefer:
- One small control window
- One region-selection overlay
- One preview window

Do not add complex settings screens unless needed.

## Capture

Use ScreenCaptureKit.

Important:
- Correctly handle Retina scaling
- Correctly convert between SwiftUI/AppKit coordinates and ScreenCaptureKit coordinates
- Support multiple displays
- Avoid capturing the Share Slice preview window recursively
- Keep capture latency low
- Avoid unnecessary frame processing

## State

Use simple SwiftUI state and lightweight model objects.

Persist only useful preferences such as:
- Last selected display
- Last capture rectangle
- Last aspect ratio

Use UserDefaults unless there is a strong reason not to.

## Error handling

Show useful errors to the user for:
- Missing Screen Recording permission
- Display becoming unavailable
- Capture failures

Do not silently ignore failures.

## Testing

Where practical, separate coordinate conversion and region calculations from UI code so they can be unit tested.

Prioritize tests for:
- Coordinate conversion
- Aspect ratio calculations
- Region bounds validation

## Build quality

Before considering a task complete:
- Build the app
- Fix compiler warnings introduced by the change
- Check for obvious runtime issues
- Keep the implementation focused on the requested feature

Do not mark work complete if the app does not build.

## Git

Keep commits focused.

Do not:
- Commit DerivedData
- Commit user-specific Xcode state
- Reformat unrelated files
- Make unrelated cleanup changes

## Scope control

If a feature starts becoming complex, implement the simplest usable version first.

Do not add:
- Analytics
- Accounts
- Cloud services
- Auto-update frameworks
- Telemetry
- Crash-reporting SDKs
- Custom networking
- Plugin systems

unless explicitly requested.