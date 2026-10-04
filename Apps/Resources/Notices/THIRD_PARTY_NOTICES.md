# Third-party notices

Application code and original artwork are provided by AetherNative. Original application, service and tool code is MIT licensed. The derived AetherVLCBridge wrapper and vendored headers retain their original LGPL and per-file notices; the repository's MIT license does not relicense these files. Third-party media libraries retain their own licenses.

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
- This is a 4.0 pre-release engine. The modified Native7 backend modifies the libVLC core derived from this fixed wrapper and VLC base `005e69e67a8730f128e44bde68437fbb048cf45f`; the official stock binary checksum is historical evidence, not the checksum of the modified core. See `docs/BACKEND_EVIDENCE.md` and `Packages/AetherVLCKit/Provenance/` for the exact input and build boundaries.
- Prepared source-input asset: `AetherFilm-v0.1.0-VLCKit-source-materials.tar.gz` (SHA-256 `350d8d23d66aff59d7734e35afe81d92f12e59a30a14b8ec575a76960601ff72`). It retains the pinned wrapper, libVLC base tree and patchset, dependency source archives, original notices and build information. Source-input verification and complete engine rebuilding are recorded separately in `docs/BACKEND_EVIDENCE.md`.
- Local core changes cover clean aperture, the GSM deployment flag, paused input/video output and decoder flush, interruption of held prefetch/HTTP/TLS reads, and preservation of original audio output timestamps for fallback drain delays at changed playback rates, and 100 ms real AVSampleBuffer and CoreAudio output-clock report intervals. The eight local patches and twelve affected-source hashes, the minimum26 configuration and three ARM64 build records are in `Packages/AetherVLCKit`. The official patched-source archive already contains the twelve official patches; rebuilding from that archive must not apply them again.
- The final corresponding-source extension must include these later changes, complete final application/bridge source, project specification and locks, portable rebuild/relink instructions, and Lua5.4.4 (360876 bytes, SHA-256 `164c7849653b80ae67bec4b7473b884bf5cc8d2dca05653475ec2ed27b9ebf61`). The unchanged older input asset does not contain that extension. Rust1.96.0, the Darwin/iOS/iOS Simulator targets and rav1e Cargo.lock/vendor input records are retained in the new provenance.

## Derived AetherVLCBridge wrapper

- Location: `Packages/AetherVLCBridge`; original wrapper revision `8f5ce02f09a7da5d061a24ddac3cb432f2a9b332` remains fixed. The original stock binary checksum `f37c8dbdd4427d1a3f5d75dc4b8bd1ae863cef4426f9a405a2fd1c5c9012f1fb` is retained as history and must not identify a modified Native7 artifact.
- The namespaced Objective-C player implementation and vendored headers retain LGPL-2.1-or-later and their original per-file copyright notices. `Packages/AetherVLCBridge/COPYING.LGPL-2.1` preserves the original license text. Modified generated files carry an AetherNative change notice dated `2026-10-03`.
- The wrapper adds typed stopping snapshots, clock/input/seek callbacks and sequencing, checks clock interpolation, and uses target-relative header imports. It uses an owned namespaced class and does not swizzle or inspect a stock player's private handle. The current core is modified separately by the patches described above.
- The package contains hashed original inputs, the exact modification patch, generators and provenance; its current reproduction proof identifies the actual 22 generated files. Earlier five-platform consumer checks, including Intel, remain historical. Current release scope is macOS arm64, iOS arm64 and iOS Simulator arm64 at minimum26. Consumer compile/link evidence and diagnostic core builds do not establish final application, device or distribution acceptance.
- Read `Packages/AetherVLCBridge/README.md` and `Packages/AetherVLCBridge/Provenance/consumer-build-review.json` for exact inputs, hashes, rebuilding tools and verification limits. The original VLCKit source-input archive above is preserved unchanged; it does not contain this later derived bridge or the final complete application source. A new asset at the same final application commit must add the complete App and bridge files, the project specification, locks, notices and relinking instructions. App and bridge inputs must correspond to the distributed executable rather than an earlier probe or candidate.
- Static application rebuilding and execution of a verification-modified bridge consumer remain separate checks until recorded against the final source commit. Complete engine rebuilding, notarized GUI execution, physical iOS installation and distribution acceptance are not established by the package consumer tests.

Binary distributions include these notices and the original license texts. Prepared dependency source materials and the final application / bridge source asset must be supplied with the published release. Rebuild and relinking evidence, including remaining verification limits, is recorded in `docs/BACKEND_EVIDENCE.md`. A package version alone does not establish the bundled components' source provenance.

## Test-only software

Impacket 0.13.0 is used only for an isolated SMB2 test fixture. It is not part of application binaries. ffmpeg is used to synthesize copyright-free media fixtures and is not bundled with the app.
