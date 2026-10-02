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

The TCP half-close compatibility fix requires a new source candidate and platform/release builds. Evidence below belongs to the preceding `402034c` candidate; it must not be used to certify the newer source tree. New playback diagnostics and CI confirmation are in progress.

2026-10-03: source commit `402034cd87fd10545d22e3ef33c8ee80473e75f0` has a built universal macOS Release and signed iOS Release archive. macOS App and DMG notarization are Accepted; tickets validate. The exact DMG was mounted read-only, with correct volume label, Applications link, licenses, icon, minimum 26.0 and no test resources. Its SHA-256 is `ee54fc8dd8a1f84604940278939c1a0e0e6cab06b73f2db3c7d60ec04d5b7600`, with 28 local inspection checks and 54 exact-candidate VM installation/signature checks passed. The VM has Gatekeeper assessments enabled; DMG and both app copies assess as Notarized Developer ID without an override. `artifacts/CANDIDATE_MANIFEST.json` records the source commit and all three asset hashes. Earlier candidates are retained under `artifacts/previous-candidates/`. See `TEST_MATRIX.md` for exact evidence and policy-assessment limitations. VM graphical acceptance, iPhone acceptance, final CI, public download and website deployment remain pending; this is an unpublished candidate.
