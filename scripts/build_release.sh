#!/bin/bash
set -euo pipefail
TASK_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$TASK_ROOT"
TASK_PLATFORM="${1:-macOS}"
xcodegen generate --spec project.yml
case "$TASK_PLATFORM" in
  macOS)
    xcodebuild build -project AetherFilm.xcodeproj -scheme AetherFilm-macOS \
      -destination 'generic/platform=macOS' -configuration Release \
      -derivedDataPath build/release-macOS ARCHS=arm64 ONLY_ACTIVE_ARCH=NO \
      CODE_SIGNING_ALLOWED=NO
    echo 'Unsigned candidate: build/release-macOS/Build/Products/Release/AetherFilm.app'
    ;;
  iOS)
    xcodebuild archive -project AetherFilm.xcodeproj -scheme AetherFilm-iOS \
      -destination 'generic/platform=iOS' -configuration Release \
      -derivedDataPath build/release-iOS -archivePath build/AetherFilm-iOS.xcarchive \
      -allowProvisioningUpdates
    echo 'Signed archive: build/AetherFilm-iOS.xcarchive'
    ;;
  *)
    echo 'Usage: scripts/build_release.sh macOS|iOS' >&2
    exit 2
    ;;
esac
