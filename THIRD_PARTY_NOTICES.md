# Third-party notices

Application code and original artwork are provided by AetherNative. Application code is MIT licensed. Third-party media libraries retain their own licenses.

## AMSMB2 and libsmb2

- Swift wrapper: https://github.com/amosavian/AMSMB2/tree/4.0.3
- Fixed wrapper commit: `1726aaaf7adf63d7d1d2a0c5d1b0e635028215c0`.
- Swift package overall: LGPL-2.1-or-later; its original Swift wrapper files identify MIT licensing.
- SMB implementation: https://github.com/sahlberg/libsmb2/tree/aff9fa6ba9f41cfd3c15d184554601ec3f6d8d03
- libsmb2: LGPL-2.1-or-later.
- AMSMB2 is supplied as a dynamic library product. The app source, exact dependency manifests and build configuration are public for rebuilding against a modified library.

## VLCKit and libVLC

- Official wrapper: https://github.com/videolan/vlckit/tree/4.0.0-a25
- Fixed wrapper commit: `8f5ce02f09a7da5d061a24ddac3cb432f2a9b332`.
- License: LGPL-2.1-or-later, subject to the bundled component notices.
- Unmodified license text: `Playback/Resources/VLCKit-LICENSE.txt`, included in the app resources.
- This is a 4.0 pre-release engine. See `docs/BACKEND_EVIDENCE.md` for artifact hash, platform slices, upstream source and build patchset evidence.

Before distributing binaries, include these notices and the original license texts, retain the exact corresponding source / patchsets / build information, and verify the rebuilt library and app linking route. Do not claim that a package version alone satisfies all bundled-component redistribution obligations. No release has been published yet.

## Test-only software

Impacket 0.13.0 is used only for an isolated SMB2 test fixture. It is not part of application binaries. ffmpeg is used to synthesize copyright-free media fixtures and is not bundled with the app.
