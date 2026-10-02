# Playback backend evidence

Inspected on 2026-10-03 (Asia/Shanghai). This records upstream and artifact
evidence. It is not an assertion that AetherFilm playback or device acceptance
has passed; executed results belong in `TEST_MATRIX.md`.

## Fixed official dependency

- Provider: VideoLAN's official [VLCKit mirror](https://github.com/videolan/vlckit).
- Version: **4.0.0-a25**, a **pre-release** of the libVLC 4 engine.
- Wrapper commit: `8f5ce02f09a7da5d061a24ddac3cb432f2a9b332`.
- [Manifest at the fixed commit](https://github.com/videolan/vlckit/blob/8f5ce02f09a7da5d061a24ddac3cb432f2a9b332/Package.swift).
- [Official binary archive](https://download.videolan.org/cocoapods/unstable/VLCKit-4.0-20260929-1631.zip).
- Archive length observed from the completed download: **922611306 bytes**.
- SHA256 calculated locally and matched against the fixed manifest:
  `f37c8dbdd4427d1a3f5d75dc4b8bd1ae863cef4426f9a405a2fd1c5c9012f1fb`.

The verified archive's `VLCKit.xcframework/Info.plist` includes all three
required platform variants:

| Library identifier | Platform | Architectures |
| --- | --- | --- |
| `macos-arm64_x86_64` | macOS | arm64, x86_64 |
| `ios-arm64` | iOS device | arm64 |
| `ios-arm64_x86_64-simulator` | iOS Simulator | arm64, x86_64 |

These entries prove artifact packaging, not successful app linking or playback.
The application keeps its minimum deployment targets at macOS 26.0 and iOS
26.0. VLCKit platform support does not change those requirements.

## Corresponding source

The framework's exported C functions returned the following values on the
local macOS artifact, without starting playback:

```text
libvlc_get_version:   4.0.0-dev Otto Chriek
libvlc_get_changeset: 4.0.0-dev-39228-gc6a26dafaf
libvlc_get_compiler:  Apple clang version 17.0.0 (clang-1700.6.4.2)
```

The short changeset `c6a26dafaf` did not resolve through the public VideoLAN VLC
GitHub/GitLab commit APIs during inspection. Do not publish it as a verified
public source URL. The fixed VLCKit
[build script](https://github.com/videolan/vlckit/blob/8f5ce02f09a7da5d061a24ddac3cb432f2a9b332/compileAndBuildVLCKit.sh)
sets `TESTEDHASH="005e69e67"`, checks out that upstream revision, and applies
`libvlc/patches/*.patch` with `git am`.

The publicly resolved upstream revision is
[`005e69e67a8730f128e44bde68437fbb048cf45f`](https://github.com/videolan/vlc/commit/005e69e67a8730f128e44bde68437fbb048cf45f)
(2026-09-29). Corresponding source inputs must include:

1. [VLCKit source at the fixed wrapper commit](https://github.com/videolan/vlckit/tree/8f5ce02f09a7da5d061a24ddac3cb432f2a9b332), including its build and packaging scripts.
2. [VLC source at the tested upstream revision](https://github.com/videolan/vlc/tree/005e69e67a8730f128e44bde68437fbb048cf45f).
3. [The wrapper commit's libVLC patch set](https://github.com/videolan/vlckit/tree/8f5ce02f09a7da5d061a24ddac3cb432f2a9b332/libvlc/patches).
4. Source, versions, build information and licenses for the bundled contrib
   dependencies, and any local changes, required for the shipped artifact.

The script explains why a patched build can report a changeset different from
its upstream base. It does not independently establish the complete provenance
of every byte in the official binary. Preserve the archive checksum and gather
the corresponding source/build materials before distribution; source links
alone are not a completed release compliance record.

## License and distribution

VLCKit's source headers identify LGPL-2.1-or-later. The official archive ships
the GNU LGPL 2.1 text as `COPYING.txt`; an unchanged copy is checked in at
[`Playback/Resources/VLCKit-LICENSE.txt`](../Playback/Resources/VLCKit-LICENSE.txt).

The release must ship this text and an accessible source notice, identify
VLCKit/libVLC and their versions, retain relevant dependency notices, and
provide the corresponding source and permitted relinking/rebuilding materials.
Publish any changes to the LGPL components. Record the chosen distribution
method and its evidence in the release checklist. A public AetherFilm source
repository by itself does not prove all component obligations are satisfied.

## Planned first-release support

The playback adapter uses the fixed VLCKit backend for MP4/MOV/MKV/AVI,
embedded and external SRT/ASS subtitles, audio track selection, chapters,
pause, seek and rate control. Generated fixtures and XCTest sources live in
`PlaybackTests/`. Successful upstream playback is not AetherFilm acceptance.

- Test each selected container/codec/subtitle combination through the app.
- Check actual decoder, displayed-picture and played-audio counters; also
  inspect pixels, Chinese glyphs/ASS style, audio and subtitle synchronization.
- Check repeated SMB seeking, disconnect/retry and close/reopen behavior.
- Test iOS on a real device, including its audio session, hardware decode,
  headphone removal and interruption behavior.
- Publish a support table based on those results. Do not claim all Infuse
  formats, Dolby Vision/Atmos, AirPlay or Picture-in-Picture support from this
  dependency's features or presence of APIs.

## Local diagnostics

The ignored `.build/Probe` directory holds the verified zip and extracted
framework for local checks. Normal project specifications retain the official
fixed remote revision. A temporary local binary target can reuse this exact
framework for diagnosis, but final reproducibility/CI must still verify the
checked-in specification and fixed official artifact.

The current standalone macOS diagnostic app is `.build/Probe/Smoke.app`.
Invoke its executable inside Tart `macos27`, supplying the generated fixture
directory as an absolute path. It emits a JSON report and exits nonzero when a
check fails. Its generated source is `.build/Probe/SmokeMain.swift`; maintained
release regression sources are `PlaybackTests/FilmPlaybackTests.swift`.
