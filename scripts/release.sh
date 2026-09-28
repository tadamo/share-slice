#!/bin/bash
set -euo pipefail

fail() { echo "Error: $*" >&2; exit 1; }
usage() {
    echo "Usage: $0 VERSION [--draft|--local]"
    echo "Tests, signs, notarizes, pushes main and a new tag, and publishes a GitHub release."
    echo "--draft uploads a draft; --local only builds the signed ZIP."
    echo "Optional overrides: DEVELOPER_ID, NOTARY_PROFILE."
}

if [[ $# -eq 1 && "$1" == --help ]]; then usage; exit 0; fi
[[ $# -ge 1 && $# -le 2 ]] || { usage >&2; exit 1; }
version="$1"
[[ "$version" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]] || fail "Version must be MAJOR.MINOR.PATCH without leading zeros."
mode=publish
if [[ $# -eq 2 ]]; then
    case "$2" in
        --draft) mode=draft ;;
        --local) mode=local ;;
        *) usage >&2; exit 1 ;;
    esac
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"
identity="${DEVELOPER_ID:-Developer ID Application: THOMAS MICHAEL ADAMO (66LB6ANTYP)}"
profile="${NOTARY_PROFILE:-share-slice-notary}"
[[ "$identity" == "Developer ID Application:"* ]] || fail "DEVELOPER_ID must be a Developer ID Application identity."

tag="v$version"
if [[ "$mode" != local ]]; then
    command -v gh >/dev/null || fail "Install GitHub CLI and run gh auth login."
    gh auth status
    [[ -z "$(git status --porcelain)" ]] || fail "Commit or stash changes before releasing."
    [[ "$(git branch --show-current)" == main ]] || fail "Switch to main before releasing."
    commit="$(git rev-parse HEAD)"
    if git show-ref --verify --quiet "refs/tags/$tag"; then fail "$tag already exists locally. Choose a new version."; fi
    remote_tags="$(git ls-remote --tags origin "refs/tags/$tag")"
    [[ -z "$remote_tags" ]] || fail "$tag already exists on origin. Choose a new version."
    github_repo="$(gh repo view "$(git remote get-url origin)" --json nameWithOwner --jq .nameWithOwner)"
fi

output="$repo_root/dist/Share-Slice-$version.zip"
[[ ! -e "$output" ]] || fail "$output already exists. Move it before rebuilding this version."
identities="$(security find-identity -v -p codesigning)"
[[ "$identities" == *"\"$identity\""* ]] || fail "Signing identity not found in Keychain: $identity"
xcrun notarytool history --keychain-profile "$profile" >/dev/null
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

ditto -c -k --keepParent "$app" "$work/Share-Slice-$version.zip"
ditto -x -k "$work/Share-Slice-$version.zip" "$work/verify"
verified_app="$work/verify/Share Slice.app"
codesign --verify --strict --verbose=2 "$verified_app"
xcrun stapler validate "$verified_app"
spctl --assess --type execute --verbose=2 "$verified_app"
mv "$work/Share-Slice-$version.zip" "$output"
printf '\nPackage: %s\n' "$output"

if [[ "$mode" != local ]]; then
    [[ "$(git rev-parse HEAD)" == "$commit" && -z "$(git status --porcelain)" && "$(git branch --show-current)" == main ]] || \
        fail "Source changed during the build. Package saved, but release stopped."
    notes="$repo_root/dist/Share-Slice-$version-notes.md"
    sed "s/Share-Slice-VERSION/Share-Slice-$version/g" .github/release-notes.md > "$notes"
    release_args=(release create "$tag" "$output" --repo "$github_repo" --verify-tag
        --title "Share Slice $version" --notes-file "$notes" --generate-notes)
    if [[ "$mode" == draft ]]; then release_args+=(--draft); fi
    git tag "$tag" "$commit"
    git push --atomic origin "$commit:refs/heads/main" "refs/tags/$tag" || \
        fail "Push failed. The local tag and ZIP remain. Resolve the push failure before uploading."
    if ! gh "${release_args[@]}"; then
        echo "Upload failed. The tag and verified ZIP are ready. Retry with:" >&2
        printf 'gh ' >&2
        printf '%q ' "${release_args[@]}" >&2
        printf '\n' >&2
        exit 1
    fi
fi
