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
python3 PlaybackTests/generate_smb_fixture.py
python3 PlaybackTests/generate_4k_fixture.py
python3 scripts/generate_ui_fixtures.py
```

The isolated SMB service is loopback-only. Its password is generated in memory. No real NAS credentials are needed. Ordinary package tests explicitly skip protocol integration when its fixture is absent; use the wrapper for a full run.

After generating fixtures, regenerate the project and use `xcodebuild build-for-testing` for the iOS scheme with `-derivedDataPath build/iOS`. Run the complete playback / persistence suite using the same virtual environment:

```sh
.build/test-venv/bin/python scripts/test_simulator_playback.py \
  --products build/iOS/Build/Products --result build/Playback.xcresult
```

The runner selects an existing iPhone Simulator; use `--device-id` when sharing simulators with other work. It runs a real isolated SMB stream alongside the container, subtitle, controls, persistence and 4K software-output cases. Individual tests have a 120-second default and 180-second maximum watchdog; the playback assertions keep their shorter deadlines. Diagnostics include raw player state/output counters and a bounded generated-fixture read timeline, never URLs or credentials. GitHub CI executes this suite; real-device hardware decode and VM GUI acceptance remain separate. Pushes changing only `docs/`, `README.md` or this guide skip the product pipeline; source, tests, resources and workflow changes always run it.

Run `scripts/test_ui.sh macOS` only in the Tart `macos27` VM. Pass a specific iOS simulator or authorized device destination for iOS tests. Preserve logs / result bundles and review screenshots; typechecks and build success do not prove playback.

## Release candidates

`scripts/build_release.sh macOS` generates the checked-in project and builds an unsigned universal candidate. `scripts/build_release.sh iOS` creates a signed device archive using the developer account configured in Xcode. Both keep their deployment target at 26.0.

After review and the tests in `docs/RELEASE.md`, use `scripts/package_macos.sh /absolute/path/AetherFilm.app` with `SIGNING_IDENTITY` and an existing `NOTARY_PROFILE`. It signs nested frameworks and the app, notarizes and staples the app and DMG, checks their signatures and emits a checksum. It never creates a tag or publishes a release; exact-candidate installation, playback and public download verification remain separate gates. Preserve corresponding source materials and third-party notices alongside the release.

Do not delete original media when removing library entries. Do not log passwords, authentication headers or credential-bearing URLs. Fix regressions with tests that exercise behavior and errors.
