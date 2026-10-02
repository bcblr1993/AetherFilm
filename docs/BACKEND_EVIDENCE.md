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

### Source mapping cross-check

The fixed default recipe's `TESTEDHASH` resolves to the upstream base above.
The official
[version-tag comparison metadata](https://api.github.com/repos/videolan/vlc/compare/4.0.0-dev...005e69e67a8730f128e44bde68437fbb048cf45f?per_page=1&page=2)
reports `ahead_by=39216`, `behind_by=0`; adding the 12 official patches gives
**39228**, matching the binary's version distance. The API's `total_commits`
is capped at 10000 for this comparison and is not the distance used here.
The fixed VLC [revision generator](https://github.com/videolan/vlc/blob/005e69e67a8730f128e44bde68437fbb048cf45f/src/Makefile.am#L751)
uses `git describe`, which identifies a commit rather than a source-tree hash.

The official archive embeds build-local changesets
`c6a26dafaf244df0cfb8154bc54540402cccb7c8` for macOS and
`48b12f61c8a08976d57d9e5d5cfbffd59f2398f9` for iOS device/simulator, both
with distance 39228. The fixed
[official CI](https://github.com/videolan/vlckit/blob/8f5ce02f09a7da5d061a24ddac3cb432f2a9b332/.gitlab-ci.yml#L75)
removes the VLC checkout between platform builds and repeats checkout plus
`git am`. An in-memory Git-object check confirmed that changing only the
committer timestamp changes a commit SHA while its tree, parent, author and
message stay identical. This explains how platform hashes can differ without
different functional source; it does not prove those historical commits were
created with otherwise identical inputs.

Independent read-only hashing of 5675 tracked index entries reproduced the
preserved patched tree `9cb4e084a5e41ba0f7037c209884d8816ef929ad`. The official
macOS dSYM matches the binary UUID and retained source declaration lines,
but its DWARF 4 line tables provide no source-file checksums. These are
consistency checks of the pinned official recipe, not an independent
attestation of every binary compilation input or a complete framework rebuild.
No extra private modification has been identified. Audit records are retained
under `.build/VLCSourceMappingAudit/`; the reconstruction/relinking limits
below remain open.

### Preserved and verified source materials

The fixed wrapper source archive has SHA256
`8e2291f2f31032414a058bc80585de2ff12864303887271020d5fb6f09e0e61b`.
The VLC base archive has SHA256
`84d2d701a234edd8c9eac0214557e654d510fac048ddc3d32163d1511a6fd5c6`.
The actual upstream Git objects were also fetched. Its base tree
`da587edb9af21bdc2f8610a60355d555c1f7a4e2` matched the official commit API.
Applying all 12 fixed wrapper patches succeeded and produced tree
`9cb4e084a5e41ba0f7037c209884d8816ef929ad`. Its exported patched-source archive
has SHA256 `448c7842896f9881592ae1c0fd0f4893f4d2848764fc492ebe0b1d494f3589a0`.

The official Apple `build.conf` selections were evaluated separately for
macOS and iOS, with no system pkg-config packages substituted. Source-only
`make fetch` completed for 65 and 64 package selections respectively. The
union contains 64 source archives (some package selections share one archive),
totaling 588984529 bytes:

- 60 archive SHA512 values matched the fixed official `SHA512SUMS` files.
- FluidLite, libnoidea and Theora fixed revisions matched their rules,
  `.githash` records and `git archive` PAX commit comments.
- The rav1e vendor archive uses the upstream `skip-hash` rule. All 228 crate
  package checksums matched the original Cargo.lock; all 15603 listed source
  file SHA256 values matched, with no missing/extra crate or unlisted source
  file. Upstream AppleDouble metadata was excluded from these source-file
  checks. This is an inner-source verification, not an official outer digest.

The ignored release-input bundle is
`.build/CorrespondingSources/AetherFilm-v0.1.0-VLCKit-source-materials.tar.gz`,
665341487 bytes, SHA256
`350d8d23d66aff59d7734e35afe81d92f12e59a30a14b8ec575a76960601ff72`.
It contains the inputs, contrib sources, component license text, a verification
manifest and rebuild/relink entry-point instructions. No user media or test
credentials are included. Publish it alongside the app after release review.
The complete framework rebuild and replacement/relink checks are still open.
Its manifest explicitly retains the inferred binary/source mapping boundary;
the local patched tree is not presented as a publicly resolved `c6a26dafaf`.

LGPL 2.1 sections 4 and 6 require source access, notices and an applicable
relinking mechanism. The GNU
[source FAQ](https://www.gnu.org/licenses/gpl-faq.en.html#CorrespondingSource)
distinguishes corresponding source from reproducing an identical binary hash.
That distinction does not excuse missing library modifications or source
inputs. A source-input bundle and a passed app playback test are separate
release evidence.

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
embedded and external SRT/ASS/WebVTT subtitles, audio track selection, chapters,
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
Launch it through `open` inside a logged-in Tart `macos27` GUI session,
supplying the generated fixture directory as an absolute path through
`--args`, and use `-o` / `--stderr` to retain its output. An SSH session without
a GUI launchd domain cannot establish window/output acceptance. It emits a
JSON report; inspect the `passed` field because `open`'s exit status does not
represent the application's test exit status. Its generated source is
`.build/Probe/SmokeMain.swift`; maintained release regression sources are
`PlaybackTests/FilmPlaybackTests.swift`.

Executed iOS Simulator diagnostics exposed two adapter issues: adding an
external subtitle after disabling subtitles created a track but did not
select it; immediate pause/play could leave a late pause command active.
The adapter now waits for and explicitly selects the added track, reports
asynchronous loading failure, and reconciles late pause events with the latest
play intent. A paused chapter selection also queues its real timestamp seek.
Subtitle errors are exposed separately from video/audio playback failures;
missing or unsupported subtitle files leave the video running, and a verified
successful retry or opening another video clears the recoverable error.
The corresponding XCTest cases assert actual resumed progression, track
selection and decoded/displayed output rather than only optimistic UI state.

The real SMB case has passed on the iOS Simulator through the production
SMB2 provider, loopback HTTP Range server and VLC player: initial output before
full-file reading, two rounds of ten remote seeks with displayed-frame
progression, stop/reopen and settled NAS byte counts. Its retained evidence is
`.build/results/iOS-SMB-VLC-control-fix-20261003-0545.xcresult` and
`.build/PlaybackEvidence/ios-smb-vlc-controls.log` (36.505 seconds, zero failures).
This does not replace macOS GUI or physical iPhone acceptance.

The subsequent full iOS Simulator playback/AppStore run, including the real
SMB fixture and non-blocking subtitle-error regression, passed all 13 tests
with zero failures in 63.205 seconds. Its result is
`.build/results/iOS-nonfatal-subtitle-full-SMB-20261003-0606.xcresult`, with log
`.build/PlaybackEvidence/ios-nonfatal-subtitle-full-smb.log`. The 4K HEVC case
produced decoded/displayed video and played audio output, but this Simulator
reported no hardware HEVC capability and no selected VideoToolbox decoder;
that result provides software-output evidence only.
