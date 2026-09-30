# Share Slice

Share part of your Mac's screen in a video call. Share Slice shows the selected area in a live window you can share in Microsoft Teams or another meeting app, without changing your display resolution.

Requires macOS 13 or later. Supports Apple Silicon and Intel Macs.

## Install

Download the ZIP from [Releases](https://github.com/tadamo/share-slice/releases), unzip it, and drag Share Slice.app to Applications.

Releases starting with v1.0.0 are signed with Developer ID and notarized by Apple. Screen Recording access still requires your permission.

## Use

1. Open Share Slice and choose a display and aspect ratio.
2. Drag the Move handle to position the capture area. Drag a corner to resize it.
3. Click Start Capture and grant Screen Recording access when prompted.
4. In a Teams meeting, click Share, choose Window, and select "🖥️ Share Slice - Share This Window". Keep that window open and unminimized. Click Show Share Window in Share Slice if you lose track of it. See [Teams sharing help](https://support.microsoft.com/en-us/teams/meetings/present-content-in-microsoft-teams-meetings).
5. Move or resize the capture area as needed, even while sharing.
6. Stop sharing in Teams when done, then click Stop Capture in Share Slice.

Share Slice remembers your display, capture area, and aspect ratio. If capture is blocked, click Open Screen Recording Settings, enable Share Slice, and reopen it if macOS asks.

## Development

Requires Xcode 15 or later. Tests require macOS 14 or later. No third-party dependencies.

Open `ShareSlice.xcodeproj`, select the ShareSlice scheme, and run. Or build from the terminal:

```sh
./scripts/build.sh
```

The script quits the running app and builds into `.build/local` using automatic signing. Sign into Xcode with the configured developer team before building. Screen Recording permission should persist across signed rebuilds.

Run tests:

```sh
xcodebuild -project ShareSlice.xcodeproj -scheme ShareSlice -configuration Debug -destination 'platform=macOS' test
```

## Release from your Mac

GitHub Actions runs tests. Create releases on your Mac using the Developer ID certificate and `share-slice-notary` Keychain profile already set up there. GitHub CLI must be signed in with `gh auth login`.

Commit your changes on `main`, then run:

```sh
./scripts/release.sh
```

The script prompts for a version. Press Enter to use the next patch version after the highest release tag found locally or on origin, or type a different version. With no release tags, the default is 0.1.0. To skip the prompt, pass a version, for example `./scripts/release.sh 1.0.1`. An explicit version is required when running without an interactive terminal.

The script tests, builds for Apple Silicon and Intel, signs, notarizes, verifies the ZIP, pushes `main` and the new version tag, and publishes the GitHub release. It includes install instructions and generated release notes. You don't need to create tags yourself.

Use `--draft` to review the release on GitHub before publishing, or `--local` to build only. Files are saved in `dist/`. Existing tags and ZIPs won't be overwritten. If upload fails after the tag is pushed, the script prints a retry command.

The signing identity and Keychain profile have defaults for this Mac. Set `DEVELOPER_ID` or `NOTARY_PROFILE` to override them on another setup. Credentials stay in Keychain.
