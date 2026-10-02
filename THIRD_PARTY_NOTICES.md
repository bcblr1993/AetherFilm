# Third-party notices

Application code and original artwork are provided by AetherNative. Application code is MIT licensed. Third-party media libraries retain their own licenses.

## AMSMB2 and libsmb2

- Swift wrapper: https://github.com/amosavian/AMSMB2/tree/4.0.3
- Fixed wrapper commit: `1726aaaf7adf63d7d1d2a0c5d1b0e635028215c0`.
- Swift package overall: LGPL-2.1-or-later; its original Swift wrapper files identify MIT licensing.
- SMB implementation: https://github.com/sahlberg/libsmb2/tree/aff9fa6ba9f41cfd3c15d184554601ec3f6d8d03
- libsmb2: LGPL-2.1-or-later.
- AMSMB2 is supplied as a dynamic library product. The app source, exact dependency manifests and build configuration are public for rebuilding against a modified library.
- Unmodified license texts: `Apps/Resources/Notices/AMSMB2-LICENSE.txt` and `Apps/Resources/Notices/libsmb2-LICENSE.txt`, included in the app resources.
- Prepared corresponding-source asset: `AetherFilm-v0.1.0-AMSMB2-source-materials.tar.gz` (SHA-256 `913d903751160f150b8e0d36880eac9299d32be58e6cb631ba7299dc998490e0`). It contains the complete exact upstream source trees, original licenses, a local SwiftPM build driver, rebuild / replacement scripts, and verification records. Its internal `MANIFEST.sha256` covers all other regular files.
- Both original and verification-modified sources rebuilt for macOS arm64 / x86_64 with deployment target 26.0. A copied app detected an invalid signature after framework replacement, then passed deep / strict verification after ad-hoc re-signing. Independent C and Swift consumers loaded the modified framework; no NAS or application UI was accessed.
- The hardened-runtime test consumers required `com.apple.security.cs.disable-library-validation` for independently ad-hoc signed libraries. This entitlement was applied only to owned verification consumers. The source asset explains local re-signing and the limits of the check; Developer ID / notarized app execution and physical iOS relinking remain separate checks.

## VLCKit and libVLC

- Official wrapper: https://github.com/videolan/vlckit/tree/4.0.0-a25
- Fixed wrapper commit: `8f5ce02f09a7da5d061a24ddac3cb432f2a9b332`.
- License: LGPL-2.1-or-later, subject to the bundled component notices.
- Unmodified license text: `Playback/Resources/VLCKit-LICENSE.txt`, included in the app resources.
- This is a 4.0 pre-release engine. See `docs/BACKEND_EVIDENCE.md` for artifact hash, platform slices, upstream source and build patchset evidence.
- Prepared source-input asset: `AetherFilm-v0.1.0-VLCKit-source-materials.tar.gz` (SHA-256 `350d8d23d66aff59d7734e35afe81d92f12e59a30a14b8ec575a76960601ff72`). It retains the pinned wrapper, libVLC base tree and patchset, dependency source archives, original notices and build information. Source-input verification and complete engine rebuilding are recorded separately in `docs/BACKEND_EVIDENCE.md`.

Binary distributions include these notices and the original license texts; source material assets are provided alongside the application on the repository's Releases page. Rebuild and relinking evidence, including remaining verification limits, is recorded in `docs/BACKEND_EVIDENCE.md`. A package version alone does not establish the bundled components' source provenance.

## Test-only software

Impacket 0.13.0 is used only for an isolated SMB2 test fixture. It is not part of application binaries. ffmpeg is used to synthesize copyright-free media fixtures and is not bundled with the app.
