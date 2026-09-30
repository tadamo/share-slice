# Make the share window easier to find

- Rename the preview to "🖥️ Share Slice - Share This Window". Use the same title in the controls and README.
- Add Show Share Window while capture is running. Restore the preview if minimized and bring it forward without restarting capture.
- Keep the preview content unchanged so instructions don't appear in the shared video.
- Build the app and check the title, control text, and show button where local permissions allow. A Teams meeting check remains manual.

## Validation

- The arm64 Debug build passed. No Swift compiler warnings appeared. Xcode reported its App Intents metadata warning because the app has no AppIntents dependency.
- Launched the local build and verified the controls display the emoji and exact new title.
- Capture startup reported missing Screen Recording permission. Live preview, minimized-window restoration, and Teams picker checks remain manual.
