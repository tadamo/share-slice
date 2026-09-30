# Release version prompt

- Make VERSION optional. With no version, prompt before building or publishing. Enter accepts the default; typed versions use the existing validation.
- Default to the next patch after the highest valid vMAJOR.MINOR.PATCH tag found locally or on origin. Ignore prerelease and unrelated tags. Use 0.1.0 when no release tags exist.
- Keep explicit versions, --draft, and --local working. Require an explicit version without an interactive terminal. Stop if origin tags can't be read.
- Update usage and README. Check Bash syntax, ShellCheck, and mocked version selection and preflight paths without signing or publishing. Build the app.

## Validation

- Bash syntax, ShellCheck, and whitespace checks passed.
- All 18 mocked checks passed, covering numeric tag sorting, remote and local defaults, no tags, Enter, custom versions, all modes, explicit versions without a terminal, invalid arguments, origin failure, existing tags, dirty checkout, and help. No signing or publishing commands ran.
- The arm64 Debug app build passed.
- Origin tag lookup failed inside the sandbox, then succeeded outside it. The highest release tag is v1.0.0, so the current default is 1.0.1.
