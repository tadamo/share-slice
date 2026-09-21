# Build and release plan

- Add a local Debug build script using Xcode and ignored `.build` output.
- Add a release script that tests on the host Mac, builds arm64 and x86_64,
  and packages a versioned ZIP under `dist`.
- Use ad hoc signing for local builds. Support Developer ID signing and
  notarization through environment variables and a Keychain profile.
- An explicit `--draft` option uploads a signed, notarized ZIP to GitHub.
  Require a clean checkout and an existing pushed version tag at HEAD.
  Leave publication to the user.
- Document commands and verify the local build, tests, and ZIP contents.
  Signing and uploads require credentials and won't be exercised automatically.

## Validation

Checked September 21, 2026 with Xcode 27.0:

- Local build passed. Release script passed all 8 tests and built both architectures.
- Verified ZIP integrity, both version fields, both binary architectures, and the
  extracted app's ad hoc signature.
- Invalid arguments, missing draft signing configuration, and an existing ZIP
  stop the script with an error.
- Xcode tests needed access outside the sandbox to Apple's test service.
- No Swift compiler warnings. The existing App Intents metadata warning remains.
- Developer ID signing, notarization, and GitHub upload remain untested with real
  credentials. No release was uploaded.
