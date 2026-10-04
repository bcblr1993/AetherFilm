#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
: "${SIGNING_IDENTITY:?Set the Developer ID Application signing identity}"
: "${NOTARY_PROFILE:?Set an existing notarytool Keychain profile}"
INPUT="${1:?Usage: scripts/package_macos.sh /absolute/path/AetherFilm.app}"
VERSION="$(awk '/^MARKETING_VERSION[[:space:]]*=/{print $3}' Version.xcconfig)"
BUILD="$(awk '/^CURRENT_PROJECT_VERSION[[:space:]]*=/{print $3}' Version.xcconfig)"
OUT="$ROOT/artifacts"
STAGE="$(mktemp -d "${TMPDIR:-/tmp}/aetherfilm-package.XXXXXX")"
DMG_STAGE="$(mktemp -d "${TMPDIR:-/tmp}/aetherfilm-dmg.XXXXXX")"
trap 'rm -rf "$STAGE" "$DMG_STAGE"' EXIT
mkdir -p "$OUT"
REPORTS="$(mktemp -d "$OUT/notarization-$VERSION.XXXXXX")"
APP="$STAGE/AetherFilm.app"
ditto "$INPUT" "$APP"
INFO="$APP/Contents/Info.plist"
ACTUAL_VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$INFO")"
[[ "$ACTUAL_VERSION" == "$VERSION" ]] || { echo 'App version differs from Version.xcconfig.' >&2; exit 1; }
[[ "$(/usr/libexec/PlistBuddy -c 'Print CFBundleVersion' "$INFO")" == "$BUILD" ]] || { echo 'App build differs from Version.xcconfig.' >&2; exit 1; }
[[ ! -d "$APP/Contents/Resources/UIFixtures" ]] || { echo 'Test fixtures cannot ship.' >&2; exit 1; }
[[ ! -d "$APP/Contents/Resources/PlaybackFixtures" ]] || { echo 'Test fixtures cannot ship.' >&2; exit 1; }
[[ ! -d "$APP/Contents/PlugIns" ]] || { echo 'Test bundles cannot ship.' >&2; exit 1; }
mkdir -p "$APP/Contents/Resources/Notices"
cp THIRD_PARTY_NOTICES.md "$APP/Contents/Resources/Notices/"
cp LICENSE "$APP/Contents/Resources/Notices/AetherFilm-LICENSE.txt"
# Sign nested code first. --deep is used only for verification below.
while IFS= read -r -d '' code; do
  codesign --force --timestamp --options runtime --sign "$SIGNING_IDENTITY" "$code"
done < <(find "$APP/Contents" -type f -name '*.dylib' -print0)
while IFS= read -r -d '' framework; do
  codesign --force --timestamp --options runtime --sign "$SIGNING_IDENTITY" "$framework"
done < <(find "$APP/Contents/Frameworks" -depth -type d -name '*.framework' -print0)
codesign --force --timestamp --options runtime --entitlements Apps/macOS/AetherFilm.entitlements --sign "$SIGNING_IDENTITY" "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"
BASENAME="AetherFilm-$VERSION-macos-arm64"
verify_apple_silicon_binary() {
  [[ "$(lipo -archs "$1")" == arm64 ]] || { echo "Expected an Apple Silicon arm64 binary: $1" >&2; exit 1; }
}
verify_apple_silicon_binary "$APP/Contents/MacOS/AetherFilm"
while IFS= read -r -d '' binary; do
  if /usr/bin/file -b "$binary" | /usr/bin/grep -q 'Mach-O'; then
    verify_apple_silicon_binary "$binary"
  fi
done < <(find "$APP/Contents/Frameworks" -type f -print0)
ZIP="$STAGE/$BASENAME.zip"
ditto -c -k --keepParent "$APP" "$ZIP"
xcrun notarytool submit "$ZIP" --keychain-profile "$NOTARY_PROFILE" --wait --timeout 10m --output-format json > "$REPORTS/app-notarization.json"
python3 - "$REPORTS/app-notarization.json" <<'PY'
import json,sys
r=json.load(open(sys.argv[1])); print('App notarization:',r.get('status'))
if r.get('status') != 'Accepted': raise SystemExit(1)
PY
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
spctl --assess --type execute "$APP"
ln -s /Applications "$STAGE/Applications"
mkdir "$STAGE/Notices"
cp THIRD_PARTY_NOTICES.md LICENSE "$STAGE/Notices/"
cp Apps/Resources/Notices/AetherVLCBridge-LICENSE.txt Apps/Resources/Notices/AetherVLCBridge-SOURCE.txt "$STAGE/Notices/"
cat > "$STAGE/安装说明.txt" <<'TEXT'
将 AetherFilm 拖入 Applications（应用程序）。需要 Apple Silicon Mac 和 macOS 26 或更新系统。
在应用中选择自己的视频，或连接 NAS 的 SMB 共享。
从应用列表移除视频不会删除原文件。
项目、支持与许可证：https://github.com/bcblr1993/AetherFilm
TEXT
rm "$ZIP"
FINAL_DMG="$OUT/$BASENAME.dmg"
[[ ! -e "$FINAL_DMG" ]] || { echo 'Refusing to replace an existing DMG; preserve the previous artifact.' >&2; exit 1; }
DMG="$DMG_STAGE/$BASENAME.dmg"
hdiutil create -volname AetherFilm -srcfolder "$STAGE" -format UDZO "$DMG"
codesign --timestamp --sign "$SIGNING_IDENTITY" "$DMG"
xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait --timeout 10m --output-format json > "$REPORTS/dmg-notarization.json"
python3 - "$REPORTS/dmg-notarization.json" <<'PY'
import json,sys
r=json.load(open(sys.argv[1])); print('DMG notarization:',r.get('status'))
if r.get('status') != 'Accepted': raise SystemExit(1)
PY
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"
spctl --assess --type open --context context:primary-signature "$DMG"
mv "$DMG" "$FINAL_DMG"
(cd "$OUT" && shasum -a 256 "$BASENAME.dmg" > SHA256SUMS.txt)
printf 'Candidate artifact: %s\n' "$FINAL_DMG"
printf 'Notarization records: %s\n' "$REPORTS"
printf 'Run exact-candidate VM installation and playback, review RELEASE.md, then publish.\n'
