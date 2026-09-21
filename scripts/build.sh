#!/bin/bash
set -euo pipefail

if [[ $# -ne 0 ]]; then
    echo "Usage: $0" >&2
    exit 1
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Quit the app before replacing its executable.
if pgrep -x 'Share Slice' >/dev/null; then
    osascript -e 'tell application id "com.tadamo.ShareSlice" to quit'
fi

xcodebuild -project "$repo_root/ShareSlice.xcodeproj" -scheme ShareSlice \
    -configuration Debug -destination "platform=macOS,arch=$(uname -m)" \
    -derivedDataPath "$repo_root/.build/local" \
    -allowProvisioningUpdates build

printf '\nApp: %s\n' "$repo_root/.build/local/Build/Products/Debug/Share Slice.app"
