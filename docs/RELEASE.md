# Release gates

Target: v0.1.0. No release has been published.

## Order

1. Finish the agreed scope, review the compatibility table, and run all applicable tests and platform builds.
2. Complete real playback and UI acceptance; preserve evidence for the exact candidate commit.
3. Verify GitHub CI. Build macOS release, sign with Developer ID, notarize, staple, mount DMG, install in the VM, and verify first launch and playback.
4. Build iOS archive with the intended team and provisioning. Install on a real iPhone and verify playback. The user accepted macOS-first public distribution with iOS built and tested alongside it. Advance TestFlight / App Store distribution as account conditions permit and report its actual state; do not add public iOS distribution as a prerequisite to the macOS-first release. If TestFlight is used, wait for processing and verify the install link before claiming availability.
5. Create a version tag and GitHub release with macOS artifact, SHA256, release notes, compatibility and explicit iOS distribution state. Never upload a simulator artifact as an installable iPhone release.
6. Download the published macOS artifact and check its hash, signature and notarization. Add the product and verified download to the AetherNative site through its existing content structure; verify the deployed page.

## Stop conditions

Failing core tests, crashes, missing playback evidence, or missing signed macOS artifacts block the macOS release. Missing iOS provisioning / device evidence blocks the iOS testing claim and must be reported explicitly; it does not silently change the accepted macOS-first distribution order. External App Store review cannot be called complete while pending. A preview release, if explicitly chosen, must state remaining limitations.

## Rollback

Retain the previous version and its hashes. Do not overwrite published artifacts in place. Correct faulty binaries with a new version. Website changes must be reversible through their scoped commit.

## Current candidate evidence

2026-10-03: the latest signed DMG is built from `c7906074451b0a8ccb0b5ad6f7f462f3ea60f4c1`. It includes TCP half-close compatibility, reconciliation of a reproduced late-pause control-state defect, and synchronous iOS audio activation on a background serial coordinator. Both platform Debug test products, universal macOS Release and an iOS Release archive were built. A local iOS 26.5 run passed 22/22 playback/AppStore/audio cases and a separate focused UI run passed 3/3. Historical complete UI results remain valid only for the source and scenarios recorded in `TEST_MATRIX.md`.

GitHub run `37075306804` passed shared tests 33/33 and all three builds, but platform tests were 21/22: natural completion after a seek failed when the wrapper's cached time rolled back from 11 to 6.179 seconds before stopping. Twenty real SMB seeks and all audio lifecycle cases passed this round; the slowest seek still approached the unchanged 12-second deadline. The complete logs contained no AudioHangRisk text and no xcresult runtime warnings. These observations do not prove SMB stability or the underlying completion cause. Evidence and earlier failed runs are retained; this is a failing release gate.

The current App and DMG notarization are Accepted; signatures and tickets validate. DMG SHA256 is `84c488982fb76402d8d47515b155de46e6b6d5c9f8b3350056f2cdac5ba4d684`; 31 local inspection checks passed, including the read-only mounted volume, licenses, icon, minimum 26.0, universal Mach-O files, and UUIDs matching the built app. `artifacts/CANDIDATE_MANIFEST.json` records three asset hashes and `publicationReady=false`. Host policy assessment is limited by its pre-existing security override. The 54 Gatekeeper-enabled VM checks and relocated Debug products belong to the preceding `5e12be2` / `fb32d110` candidate, retained in `artifacts/previous-candidates/0.1.0-fb32d110/`; they do not certify the new DMG. The VM remains at its login window and no GUI first-launch/playback or UI acceptance has run.

The current iOS archive passed 32 signature/file inspections with minimum 26.0, iPhone/iPad support, arm64, icon and licenses, and no test bundles/fixtures. It is signed with Apple Development and `get-task-allow=true`, not an App Store/TestFlight distribution export. It has not been installed on the locked real iPhone.

Subsequent settings fixes show visible native subtitles-size and volume captions. The DEBUG UI appearance helper now preserves the system font unless an explicit test override is supplied. Four targeted runs passed: settings, native slider adjustments at the standard system size, actual accessibility-extra-large, and the maximum system size with no override. Original screenshots and app/dylib byte identity are recorded in `.build/UILabelEvidence/review.json`. Earlier controlled-font results were reclassified without deleting their evidence. The current signed DMG predates these settings fixes; final source needs new builds, packaging and exact-candidate acceptance.

No tag, release, public download or website deployment has been completed. Core CI, macOS graphical acceptance, iPhone playback acceptance, full-app maximum typography/VoiceOver and the remaining compatibility matrix are open. The isolated website candidate has passed checks and browser review but remains unpublished. See `TEST_MATRIX.md` for exact evidence and limitations.
