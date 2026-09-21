#!/bin/bash
set -euo pipefail

if [[ $# -ne 0 ]]; then
    echo "Usage: $0" >&2
    exit 1
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Don't replace the executable while the app is using its old permission.
if pgrep -x 'Share Slice' >/dev/null; then
    osascript -e 'tell application id "com.tadamo.ShareSlice" to quit'
fi

xcodebuild -project "$repo_root/ShareSlice.xcodeproj" -scheme ShareSlice \
    -configuration Debug -destination "platform=macOS,arch=$(uname -m)" \
    -derivedDataPath "$repo_root/.build/local" \
    CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual build

# Ad hoc signatures change on rebuild, leaving stale Screen Recording consent.
if tccutil reset ScreenCapture com.tadamo.ShareSlice; then
    printf '\nScreen Recording permission reset. Grant access again when starting capture.\n'
else
    printf '\nWarning: could not reset Screen Recording permission. If capture is blocked, run:\n  tccutil reset ScreenCapture com.tadamo.ShareSlice\n' >&2
fi

printf '\nApp: %s\n' "$repo_root/.build/local/Build/Products/Debug/Share Slice.app"
