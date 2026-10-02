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

2026-10-03: the latest signed DMG candidate is built from `5e12be2fb9f62923ce3477ad590e79065b667135`, including the TCP half-close compatibility fix. Both platform Debug test products and a signed iOS Release archive were also rebuilt from it. Shared tests passed 33/33; a fresh iOS 26.5 Simulator playback/AppStore run passed 13/13, including two real SMB opens and 20 seeks. The unchanged UI layout source has a completed iOS 19/19 run and additional system-font/gesture checks. New playback changes address an independently reproduced late-pause control-state defect and move synchronous iOS audio activation off MainActor. Their universal macOS Release and signed iOS Release archive builds succeeded, and a fresh complete iOS 26.5 run passed 22/22, including four actual audio-preparation lifecycle regressions. The preceding signed DMG does not certify these changes; new packaging and three focused UI checks are in progress. Final iOS 27 GitHub CI and device/desktop graphical acceptance remain separate gates.

The current App and DMG notarization are Accepted; signatures and tickets validate. The exact DMG was mounted read-only, with correct volume label, Applications link, licenses, icon, minimum 26.0 and no test resources. Its SHA-256 is `fb32d110b58e0c17d61120ea8375677352a9846d9e2368f5f6ce665406690c74`, with 31 local inspection checks passed, including both Mach-O UUIDs matching the current compiled universal application. `artifacts/CANDIDATE_MANIFEST.json` records the source commit and all three asset hashes. The host's pre-existing security override prevents its policy assessment from proving enforced Gatekeeper behavior; independent exact-candidate VM checks passed 54/54 with Gatekeeper enabled and no assessment override. Current Debug test products also have matching hashes and relocated paths in the VM. Its GUI session remains at the login window; first launch/playback and UI tests have not run. The signed iOS archive has minimum 26.0, iPhone/iPad support, arm64, icon and licenses, no test bundles/fixtures, and a verified team/signature; it has not been installed on the locked iPhone.

GitHub run `37070907202` attempt 1 passed shared tests and all builds but failed 2 of 13 playback cases on iOS 27. Slow reads and CoreAudio overload were observed; both the original result and diagnostics are retained. An unchanged-source failed-job rerun (attempt 2) also failed; its exact failed cases and diagnostics are being compared independently. The runner comparison does not replace the original failed evidence or establish the underlying cause. The candidate is explicitly `publicationReady=false` while CI and graphical/device gates remain open.

Previous source `402034c` / DMG `ee54fc8d` is retained under `artifacts/previous-candidates/0.1.0-ee54fc8d/`. Its 28 local and 54 Gatekeeper-enabled VM installation/signature checks remain valid only for that preceding candidate. Older candidates are also preserved. See `TEST_MATRIX.md` for precise evidence and limitations. VM graphical acceptance, iPhone acceptance, final CI, public download and website deployment remain pending; this is an unpublished candidate.
