# Contributing

First-release scope is local files and SMB NAS playback on native macOS 26+ / iOS 26+ apps. Read `docs/PRODUCT.md` before adding features.

## Build

Use Xcode 27 and XcodeGen. Versions and minimum OS values are in `Version.xcconfig`; `project.yml` is the source of truth for the generated project.

```sh
xcodegen generate
xcodebuild build -project AetherFilm.xcodeproj -scheme AetherFilm-macOS -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO
xcodebuild build -project AetherFilm.xcodeproj -scheme AetherFilm-iOS -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO
```

Both media dependencies are fixed. The official VLCKit binary download is approximately 880 MiB; do not replace it with an unverified mirror or commit the extracted framework.

## Tests

```sh
swift test --package-path Packages/AetherFilmKit
python3 -m venv .build/test-venv
.build/test-venv/bin/python -m pip install -r scripts/test-requirements.txt
.build/test-venv/bin/python scripts/test_smb_integration.py -- swift test --package-path Packages/AetherFilmKit
python3 PlaybackTests/generate_fixtures.py
python3 scripts/generate_ui_fixtures.py
```

The isolated SMB service is loopback-only. Its password is generated in memory. No real NAS credentials are needed. Ordinary package tests explicitly skip protocol integration when its fixture is absent; use the wrapper for a full run.

Run `scripts/test_ui.sh macOS` only in the Tart `macos27` VM. Pass a specific iOS simulator or authorized device destination for iOS tests. Preserve logs / result bundles and review screenshots; typechecks and build success do not prove playback.

Do not delete original media when removing library entries. Do not log passwords, authentication headers or credential-bearing URLs. Fix regressions with tests that exercise behavior and errors.
