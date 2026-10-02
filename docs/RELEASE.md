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
