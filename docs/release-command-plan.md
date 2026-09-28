# Release command

- Extend scripts/release.sh. VERSION publishes, --draft uploads a draft, and
  --local only creates a ZIP. All modes require signing and notarization.
- Default to the existing Developer ID identity and Keychain profile, allowing
  environment overrides. Never store credentials in the repository.
- For GitHub releases, require clean main and an unused local and remote tag.
  Verify GitHub authentication and signing credentials before building.
- Test and build both architectures, sign, notarize, and check the extracted ZIP.
- Recheck the source commit and working tree before creating the tag. Atomically
  push main and the tag, then upload with the install notes and generated changes.
- If upload fails after pushing the tag, print an exact retry command using the
  already verified ZIP. Never overwrite a release or remove tags automatically.
- Validate shell syntax and mocked release paths without publishing a release.
  Run the app build and tests.

## Validation

- Bash syntax, ShellCheck, and git diff whitespace checks passed.
- Simulated publish, draft, and local builds passed. Dirty checkout, existing tags,
  missing identity, build failure, rejected notarization, failed verification,
  push failure, and upload failure all stopped as expected.
- App build and all 10 geometry tests passed. The existing App Intents metadata
  warning remains. No release was published while testing this script change.
