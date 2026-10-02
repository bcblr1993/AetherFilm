#!/bin/bash
set -euo pipefail

TASK_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TASK_PLATFORM="${1:-}"
TASK_DESTINATION="${2:-}"
TASK_RESULTS="${AETHERFILM_UI_RESULTS:-$TASK_ROOT/build/ui-results}"
TASK_SIGNING="${AETHERFILM_UI_SIGNING:-NO}"

if [[ "$TASK_PLATFORM" != "macOS" && "$TASK_PLATFORM" != "iOS" ]]; then
  echo "Usage: scripts/test_ui.sh macOS|iOS [xcodebuild destination]" >&2
  exit 2
fi

if [[ "$TASK_PLATFORM" == "macOS" ]]; then
  # Desktop automation belongs in the dedicated macos27 VM, never on the host Mac.
  if ! system_profiler SPHardwareDataType 2>/dev/null | /usr/bin/grep -q "VirtualMac"; then
    echo "macOS UI tests must run inside the Tart macos27 virtual machine." >&2
    exit 2
  fi
  TASK_DESTINATION="${TASK_DESTINATION:-platform=macOS}"
else
  if [[ -z "$TASK_DESTINATION" ]]; then
    echo "Pass an explicit iOS simulator or device destination; the script never chooses a personal device." >&2
    exit 2
  fi
fi

mkdir -p "$TASK_RESULTS"
TASK_STAMP="$(date -u +%Y%m%dT%H%M%SZ)-$$"
TASK_RESULT_BUNDLE="$TASK_RESULTS/$TASK_PLATFORM-$TASK_STAMP.xcresult"
TASK_LOG="$TASK_RESULTS/$TASK_PLATFORM-$TASK_STAMP.log"

cd "$TASK_ROOT"
if [[ ! -f ".build/UIFixtures/片段 01.mp4" || ! -f ".build/UIFixtures/片段 02.mkv" ]]; then
  python3 scripts/generate_ui_fixtures.py
fi

if [[ ! -d ".build/PlaybackFixtures" ]]; then
  python3 PlaybackTests/generate_fixtures.py
fi
for TASK_FIXTURE in clip-h264.mp4 clip-hevc.mov clip-mpeg4.avi clip-multitrack.mkv broken.mkv external.srt external.ass; do
  if [[ ! -f ".build/PlaybackFixtures/$TASK_FIXTURE" ]]; then
    echo "Incomplete playback fixtures: $TASK_FIXTURE is missing. Generate a fresh PlaybackTests fixture folder before testing." >&2
    exit 2
  fi
done

xcodegen generate --spec "$TASK_ROOT/project.yml" --project "$TASK_ROOT"

set +e
xcodebuild test \
  -project AetherFilm.xcodeproj \
  -scheme "AetherFilm-$TASK_PLATFORM" \
  -destination "$TASK_DESTINATION" \
  -derivedDataPath "$TASK_ROOT/build/ui-derived-$TASK_PLATFORM" \
  -resultBundlePath "$TASK_RESULT_BUNDLE" \
  -only-testing:"AetherFilmUITests-$TASK_PLATFORM" \
  -collect-test-diagnostics never \
  -parallel-testing-enabled NO \
  CODE_SIGNING_ALLOWED="$TASK_SIGNING" \
  | tee "$TASK_LOG"
TASK_TEST_EXIT="${PIPESTATUS[0]}"
set -e

if [[ -d "$TASK_RESULT_BUNDLE" ]]; then
  xcrun xcresulttool export attachments \
    --path "$TASK_RESULT_BUNDLE" \
    --output-path "$TASK_RESULTS/$TASK_PLATFORM-$TASK_STAMP-attachments"
fi
echo "UI result: $TASK_RESULT_BUNDLE"
exit "$TASK_TEST_EXIT"
