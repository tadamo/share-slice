# Share Slice

Share part of your Mac's screen in a video call. Share Slice shows the selected area in a live window you can share in Microsoft Teams or another meeting app, without changing your display resolution.

Requires macOS 13 or later. Supports Apple Silicon and Intel Macs.

## Install

Download the ZIP from [Releases](https://github.com/tadamo/share-slice/releases), unzip it, and drag Share Slice.app to Applications.

The app isn't notarized. If macOS blocks it, open System Settings > Privacy & Security and choose Open Anyway.

## Use

1. Open Share Slice and choose a display and aspect ratio.
2. Drag the Move handle to position the capture area. Drag a corner to resize it.
3. Click Start Capture and grant Screen Recording access when prompted.
4. In a Teams meeting, click Share, choose Window, and select Meeting Share Window. Keep that window open and unminimized. See [Teams sharing help](https://support.microsoft.com/en-us/teams/meetings/present-content-in-microsoft-teams-meetings).
5. Move or resize the capture area as needed, even while sharing.
6. Stop sharing in Teams when done, then click Stop Capture in Share Slice.

Share Slice remembers your display, capture area, and aspect ratio. If capture is blocked, click Open Screen Recording Settings, enable Share Slice, and reopen it if macOS asks.

## Development

Requires Xcode 15 or later. Tests require macOS 14 or later. No third-party dependencies.

Open `ShareSlice.xcodeproj`, select the ShareSlice scheme, and run. Or build from the terminal:

```sh
./scripts/build.sh
```

The script quits the running app, builds into `.build/local`, and resets its Screen Recording permission. Grant access again on the next capture.

Run tests:

```sh
xcodebuild -project ShareSlice.xcodeproj -scheme ShareSlice -configuration Debug -destination 'platform=macOS' test
```
