#!/bin/bash
set -euo pipefail

if [[ $# -ne 0 ]]; then
    echo "Usage: $0" >&2
    exit 1
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
xcodebuild -project "$repo_root/ShareSlice.xcodeproj" -scheme ShareSlice \
    -configuration Debug -destination "platform=macOS,arch=$(uname -m)" \
    -derivedDataPath "$repo_root/.build/local" \
    CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual build

printf '\nApp: %s\n' "$repo_root/.build/local/Build/Products/Debug/Share Slice.app"
