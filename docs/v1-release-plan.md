# v1.0.0 release

- Update install notes for Developer ID signing and Apple notarization.
- Run the release script with the existing signing identity and notarization profile.
- Verify tests, universal architectures, version, and the extracted ZIP's signature,
  notarization ticket, and Gatekeeper assessment.
- Commit the release notes and validation results, then push the v1.0.0 tag.
- Publish the verified ZIP as v1.0.0 and delete the v0.1.0 release and v0.1.1 draft.
  Keep the old Git tags as source history.
- Screen Recording approval and persistence need a manual check on the installed app.

## Validation

- All 10 geometry tests passed. Release built for arm64 and x86_64.
- Extracted ZIP reports version 1.0.0 and the expected Developer ID and team.
- Apple accepted notarization. Stapled ticket validation and Gatekeeper passed.
- Signature verification passed outside the sandbox, which could not access the
  signing trust services. GitHub reads also needed network access outside it.
- No Swift compiler warnings. Xcode emitted the existing App Intents metadata
  warning and test-host connection messages, but tests passed.
- Screen Recording behavior has not been manually verified for this release.
