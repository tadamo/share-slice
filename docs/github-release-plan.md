# GitHub release plan

- Run a GitHub Actions workflow when a `vMAJOR.MINOR.PATCH` tag is pushed.
- Reuse `scripts/release.sh` to run geometry tests and build a universal Mac app.
- Package the app as a versioned ZIP and include installation steps in the release.
- Validate the tag before building. Give only the release job write access.
- Keep repeat runs from overwriting an existing published release.
- Use ad hoc signing without extra secrets. Label downloads as unnotarized and
  document macOS Open Anyway. Keep the existing local Developer ID path.
- Check workflow syntax, run the release build locally, and inspect the archive.
  GitHub execution and Apple notarization need their respective credentials.

## Validation

- Local release build passed all 10 geometry tests and built arm64 and x86_64.
- Extracted ZIP passed integrity and code-signature checks. App version was 0.1.1.
- Workflow YAML parsed; Bash steps and the release script passed ShellCheck.
- The first test attempt hit the sandbox restriction on Apple's test service.
  The run outside the sandbox passed.
- Only the existing App Intents metadata warning appeared.
- GitHub execution and browser-downloaded Gatekeeper behavior remain untested.
  No tag was pushed and no release was published.
