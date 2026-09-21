#!/bin/bash
set -euo pipefail

fail() { echo "Error: $*" >&2; exit 1; }
usage() {
    echo "Usage: $0 VERSION [--draft]"
    echo "Optional environment: DEVELOPER_ID, NOTARY_PROFILE (set both)."
    echo "--draft requires signing, notarization, and a clean, pushed vVERSION tag at HEAD."
}

[[ $# -ge 1 && $# -le 2 ]] || { usage >&2; exit 1; }
version="$1"
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "Version must be MAJOR.MINOR.PATCH."
draft=false
if [[ $# -eq 2 ]]; then
    [[ "$2" == --draft ]] || { usage >&2; exit 1; }
    draft=true
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"
identity="${DEVELOPER_ID:-}"
profile="${NOTARY_PROFILE:-}"
if [[ -n "$identity" || -n "$profile" ]]; then
    [[ "$identity" == "Developer ID Application:"* && -n "$profile" ]] || \
        fail "Set DEVELOPER_ID to a Developer ID Application identity and NOTARY_PROFILE to a Keychain profile."
fi

tag="v$version"
if $draft; then
    [[ -n "$identity" ]] || fail "Draft uploads require DEVELOPER_ID and NOTARY_PROFILE."
    command -v gh >/dev/null || fail "Install GitHub CLI to upload a draft."
    gh auth status
    [[ -z "$(git status --porcelain)" ]] || fail "Commit or stash changes before uploading a release."
    commit="$(git rev-parse HEAD)"
    tag_commit="$(git rev-parse --verify "refs/tags/$tag^{commit}")" || fail "Create and push tag $tag first."
    [[ "$tag_commit" == "$commit" ]] || fail "$tag must point to HEAD."
    remote_tags="$(git ls-remote origin "refs/tags/$tag" "refs/tags/$tag^{}")"
    remote_commit="$(printf '%s\n' "$remote_tags" | awk 'NF == 2 { hash=$1 } END { print hash }')"
    [[ "$remote_commit" == "$commit" ]] || fail "Push $tag to origin at HEAD first."
    github_repo="$(gh repo view "$(git remote get-url origin)" --json nameWithOwner --jq .nameWithOwner)"
fi

output="$repo_root/dist/Share-Slice-$version.zip"
[[ ! -e "$output" ]] || fail "$output already exists. Move it before rebuilding this version."
mkdir -p "$repo_root/.build/releases" "$repo_root/dist"
work="$(mktemp -d "$repo_root/.build/releases/$version.XXXXXX")"
common=(-project "$repo_root/ShareSlice.xcodeproj" -scheme ShareSlice -derivedDataPath "$work/DerivedData")

xcodebuild "${common[@]}" -configuration Debug \
    -destination "platform=macOS,arch=$(uname -m)" \
    CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual test
xcodebuild "${common[@]}" -configuration Release -destination 'generic/platform=macOS' \
    'ARCHS=arm64 x86_64' ONLY_ACTIVE_ARCH=NO \
    "MARKETING_VERSION=$version" "CURRENT_PROJECT_VERSION=$version" \
    CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual build

app="$work/DerivedData/Build/Products/Release/Share Slice.app"
architectures="$(lipo -archs "$app/Contents/MacOS/Share Slice")"
[[ " $architectures " == *" arm64 "* && " $architectures " == *" x86_64 "* ]] || \
    fail "Expected arm64 and x86_64; found $architectures."
if [[ -n "$identity" ]]; then
    codesign --force --sign "$identity" --options runtime --timestamp "$app"
    codesign --verify --strict --verbose=2 "$app"
    ditto -c -k --keepParent "$app" "$work/notarization.zip"
    xcrun notarytool submit "$work/notarization.zip" --keychain-profile "$profile" \
        --wait --output-format plist > "$work/notarization-result.plist"
    status="$(/usr/libexec/PlistBuddy -c 'Print :status' "$work/notarization-result.plist")"
    [[ "$status" == Accepted ]] || fail "Notarization status: $status. See $work/notarization-result.plist."
    xcrun stapler staple "$app"
    xcrun stapler validate "$app"
    spctl --assess --type execute --verbose=2 "$app"
else
    echo "Local package uses ad hoc signing. Public distribution needs Developer ID signing and notarization."
fi

ditto -c -k --keepParent "$app" "$work/Share-Slice-$version.zip"
mv "$work/Share-Slice-$version.zip" "$output"
printf '\nPackage: %s\n' "$output"

if $draft; then
    gh release create "$tag" "$output" --repo "$github_repo" --verify-tag --draft \
        --title "Share Slice $version" --generate-notes
fi
