# Playback backend evidence

Updated on 2026-10-04 (Asia/Shanghai). This records upstream and artifact
evidence and scoped diagnostic results. These results are not an assertion
that the final combined AetherFilm candidate or device acceptance has passed;
the release acceptance matrix remains in `TEST_MATRIX.md`.

## Current Native7 source and execution boundary

The pinned ARM64 component adds `Patches/coreaudio-cadence.patch` (SHA256
`3b972cf0699962de78599575e568f0cd685ec1c9adc8f3c9227e313f65b66b4a`).
CoreAudio reports real output timestamps every 100 ms instead of one second.
The patch does not interpolate clocks or change playback rate, drain, flush,
audio-output selection, test assertions or deadlines. The earlier sample-buffer
clock correction remains included.

All three affected C objects and both wrapper targets on each platform actually
built successfully. The eight local patches and twelve affected source files
were independently verified against the corresponding source materials.
Each full archive changed exactly one member; all other member payloads and
the generated 302-module definitions were preserved. The three ARM64 slices
retain minimum OS 26.0, SDK 27.0 and platform values 1/7/2.

`VLCKit-AetherFilm-native7-arm64.xcframework.zip` is 68,726,561 bytes, SHA256
`f629ad7fd1f02aa3fef00a1808bf85e8ccb7b6916c5263d0b0238faaad261e35`.
`Package.swift`, `Provenance/artifact.json`, `native7-build-record.json` and
`native7-material-verification.json` record this component. These are verified
incremental builds; a fresh complete portable source rebuild has not executed.
The component and corresponding source are public in technical prerelease
`vlckit-8f5ce02-aether-20261004`; all three assets were anonymously downloaded
in full with matching byte counts and SHA256. This is dependency availability,
not an App release.

The same compiled App passed the original unfiltered Mac 53-case suite on the
macos27 VM: 53 passed, zero failed or skipped, exit 0. The half-speed regression
retained its original 11.9-second tail assertion and 30-second limit. Last real
normal time was 12.276241, input time 12.25, and EOS arrived at 24.935 seconds;
normal-clock cadence measured 107 ms. Exact source, products, configuration,
strict seals and owned-runner cleanup passed before and after execution.
The corresponding iOS27 and26.5 Simulator full61 suites also passed61/0/0.
Physical iPhone27.0.1 full61 was59/2/0, and a bounded two-case trace reproduced
both tail-seek completion failures. Native EOS preceded any new target normal
clock, with stale input still captured; its native drain timing is under
investigation. Physical-device and distribution acceptance remain separate
gates in `TEST_MATRIX.md`.

## Historical Native6 source and execution boundary

The preceding pinned dependency was the Native6 ARM64 component. It retained the
Native5 audio output-domain fix and adds
`Patches/output-clock-cadence.patch` (SHA256
`d3b6d69a5c9c2f4d623824dade2f1cab5eaf37240815a969c5d5c192ea74051f`).
The production sample-buffer output clock reports every 100 ms instead of one
second; application progress still uses actual output timestamps.

All three actual wrapper builds passed both targets. Their macOS, iOS Device
and iOS Simulator slices are ARM64, minimum OS 26.0, SDK 27.0, with native
platform values 1/2/7 and all 302 generated modules defined. The seven local
patches and eleven affected source files are pinned in the checked-in native
source materials. This records incremental builds, not a fresh complete
portable source rebuild.

The assembled `VLCKit-AetherFilm-native6-arm64.xcframework.zip` is 68,725,880
bytes, with measured SwiftPM checksum
`ced058ad2baa7cb74b4b1a842abbc0573a6f3bf6ddcd11f83c04d997c8414005`.
The historical package and artifact records pinned this component. It was
superseded before its planned technical prerelease was published.

The final combined candidate passed the unfiltered 61-case playback suites on
iOS 27 and iOS 26.5 Simulators (61 passed, zero failed or skipped on each).
The added tail-read failure regression proves an automatic 95-percent watched
checkpoint was persisted before a real source read failed, then persisted as
unwatched afterwards. These results do not certify physical-device, macOS,
UI or distribution acceptance; `TEST_MATRIX.md` records those gates.

## Historical Native5 source and execution boundary

The current candidate modifies libVLC; the official stock artifact below is
historical provenance. The fixed wrapper revision remains
`8f5ce02f09a7da5d061a24ddac3cb432f2a9b332`, with VLC base
`005e69e67a8730f128e44bde68437fbb048cf45f`. Checked-in source materials live in
`Packages/AetherVLCKit/{Patches,Configuration,Tools,Provenance}`. They identify
the clean-aperture, GSM deployment, paused-preview/decoder, held-IO and audio
output-domain patches, the minimum26 configuration, source assets and actual
build argv. The earlier Native4 inputs and execution records remain preserved.

The sixth local patch, `Patches/audio-output-domain.patch`, has SHA256
`ac1fe50261f73b86a1a9a111c8cd440e430cf8f6e14400451a5a5706582bf2d7`.
It preserves the original output audio timestamp before playback-rate
conversion and uses that output domain for fallback drain delay. The patch was
applied without fuzz to the unchanged original `src/audio_output/dec.c`; its
result matches the source actually compiled for all three platforms. The
current source materials pin ten affected files and retain the original five
patches and their earlier verification.

Each Native5 platform compiled one production `dec.o` and replaced only
`libvlccore_la-dec.o` in its Native4 core and full static archives. Every other
native member's payload and order stayed exact:

| Platform | Core members / other exact | Full members / other exact |
| --- | ---: | ---: |
| macOS ARM64 | 180 / 179 | 6562 / 6561 |
| iOS Simulator ARM64 | 178 / 177 | 6266 / 6265 |
| iOS Device ARM64 | 178 / 177 | 6269 / 6268 |

All six wrapper target executions exited 0. Each actual slice is thin ARM64,
minimum OS 26.0, SDK 27.0, with the correct native platform 1/7/2 and all 302 generated
modules defined. Public headers remain byte-identical to Native4, with public
libVLC version-header components 4.0.0; these are header and component checks,
not a new runtime version query. Root independently inspected the three
Mach-O hashes and versions and matched the generated module lists against
actual `nm -U` definitions. Evidence:
`Packages/AetherVLCKit/Provenance/native5-build-record.json` and
`.build/Native5ComponentRootReview20261004-r1/REVIEW.json`.

The three-slice component was actually assembled at
`.build/Native5Assembly20261004-r1/Assembly-r1/LocalVLCKit`.
`VLCKit-AetherFilm-native5-arm64.xcframework.zip` is 68726145 bytes, with measured
SwiftPM checksum
`aceb831c88c8eaec4c2248ae2c20663a8ae499e5f52e759ea903ea6cab8c3a98`.
The Native5 manifest and artifact record pinned that historical component;
its remote release asset was not published. Assembly preserved the original
framework payloads and did not compile or sign an App.

The independent iOS 27 Simulator half-speed functional regression passed
1/1, zero failed or skipped. Its 12-second sample played naturally at 0.5x and
reported actual EOS at 24.572203292 seconds, with completion 22.056339375 seconds
after early real output readiness: above the 21.202476-second lower bound and
within the new independent 30-second window. Final normal/input times were
12.071934/12.067595, displayed video 349, played audio 562, one completion and no
error. Evidence:
`.build/NativeHalfSpeedEOSRegression20261004-r1/ACTUAL_FUNCTIONAL_REVIEW.json`.
The separate original 60-second diagnostic recorded 48.419006625 seconds before
the C correction and 24.583846917 afterwards; that diagnostic is retained and
excluded from the functional suite. These single-case results do not certify
the final unified Native5 App's full 54-case iOS or 46-case Mac playback suites,
UI, physical-device or distribution acceptance.

### Historical Native4 incremental run and source preparation

The Native4 held-IO patch SHA256 is
`2cd23d50c90440d8ecdda03bf872d03ddcb5cfd0e16166a7660a0fd990b77b6e`.
Actual Mac, iOS Simulator and iOS Device incremental runs each passed all
16 subprocess stages. Four production C objects replace seven full-archive
members and one core-archive member, retaining every other native member's
payload and order and all protected original inputs. Mac preserves6555 other
full members; Simulator6259; Device6262. This is incremental build evidence,
not a fresh complete source rebuild, original App held-tail recovery proof,
new wrapper/App runtime acceptance or distribution evidence.

The complete five-patch chain was also applied with zero fuzz to nine exact
files from the official patched-source archive; all five patch commands
passed, and eight final files match the actual production candidate sources.
That source-only check does not compile or run the portable rebuilding tools.

The older source-input asset remains unchanged and reusable. Its patched VLC
tar already includes the twelve official patches, so they must not be applied
again. The final source extension still needs the final application commit,
complete App/Bridge/specification/locks, later local patches and instructions,
and Lua5.4.4 (360876 bytes, SHA256
`164c7849653b80ae67bec4b7473b884bf5cc8d2dca05653475ec2ed27b9ebf61`).
Rust/Cargo1.96.0 and the Darwin/iOS/iOS Simulator targets are recorded alongside
the rav1e Cargo.lock SHA256
`e71efcea949f8cfa31fad962ae69a7e2c17f08fb7924def3d2863e5fb37799ae` and
the earlier228 crate /15603 source-file vendor audit. This preparation does
not assert a fresh complete contrib audit or an assembled/published extension.
The final extension tool still requires the final clean application HEAD and
has not been executed for this release. The historical Native5 checksum is
measured above; signed App, UI, physical-device and release gates remain
separate. `TEST_MATRIX.md` is the authoritative acceptance record.

## Historical fixed official dependency

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

## Typed completion and SMB source health

The stock fixed VLCKit wrapper exposes a stopped state without the typed
libVLC stopping reason needed here. Its cached time can also contain a seek
target before playback reaches that target. The source-controlled
[`AetherVLCBridge`](../Packages/AetherVLCBridge/README.md) derives a namespaced
player from the exact official wrapper inputs and adds stopping reason,
input time/error, clock and input-position callbacks. Primitive stopping
values are copied under an owned lock before the delegate event is queued;
the stopping enum has a compile-time check against the fixed public C ABI.
Those historical bridge-only checks used the unchanged stock libVLC binary.
This route neither adopts the private
handle of a stock player nor swizzles its class, and retains the original
LGPL notices and generated-source provenance.

The frozen bridge's optional Swift delegate calls and Objective-C selectors
compiled and strongly linked on macOS arm64/x86_64, iOS arm64 and Simulator
arm64/x86_64, with minimum version 26.0. The exact inputs and five-platform
records are in `Packages/AetherVLCBridge/Provenance/consumer-build-review.json`.
Those were independent consumers using a verified local mirror of the fixed
binary, not a full app test or a libVLC framework rebuild.

Typed EOS does not establish source integrity. An isolated 12-second
frequent-keyframe fixture held back the last **391 of 796257 bytes**, after
actual video/audio output had reached the tail. Both active FIN and RST then
produced typed EOS and input time 12.0; a near-end time gate alone incorrectly
called completion. The FIN run recorded actual clock 11.984114, displayed
counter 7 and played-audio counter 82 before the fault. Healthy release of
the held bytes passed. The failing controls remain in
`.build/NamespacedVLCWrapperProbe/near-tail-negative-review.json`,
`tail-fin-http-evidence.json`, `tail-rst-http-evidence.json` and their test logs.
These generic HTTP fixtures established the failure mode, not a physical NAS
outage or a successful SMB health integration.

The shared `SMBStreamingServer` now publishes a sticky sanitized
`readFailure()` on its actor before invoking the observer and closing a
failed response. Provider errors, premature empty data and oversized replies
qualify; valid nonempty short chunks continue. Consumer RST/send errors,
cancelled or obsolete requests, seek cancellation and stop do not qualify.
The state survives stop, failed instances reject new connections, and
explicit Retry creates a clean instance. The application observer supplies
the error/retry UI, but completion awaits the actor query directly. Its
`canCompletePlayback` rechecks generation, source item and presented item
after the await; completion checks again after persistence. Manual next and
cleanup retain their originating generation, including same-item reopen.

The 95% watched policy is separate from final completion and automatic next.
`allowsAutomaticWatched: false` persists an unconfirmed near-end seek as a
resume checkpoint without marking watched. Confirmed playback that already
crossed 95% may legitimately remain watched after a later source failure;
that history does not authorize an EOS callback to advance the queue or
replace the last checkpoint with duration.

Scoped executed evidence on 2026-10-03:

- The complete shared package run passed **41/41, zero failed, zero skipped**:
  28 source/protocol tests, 9 domain tests and 4 persistence tests. The local
  Impacket 0.13.0 loopback fixture enabled the real SMB cases, including wrong
  credentials; fake readers exercised late cancellation, early empty data,
  sticky failure, clean Retry and actual TCP RST/half-close behavior. Log:
  `.build/shared-source-health-full-smb.log`, SHA256
  `a50f45887a6ea93f2d38c6d7e08f56d67d72a05dfe23ecc2597ce3774d40c6da`;
  provenance: `.build/ConfirmedProgressEvidence/source-health-shared-review.json`
  and `.build/EOFSourceHealthProbe/formal-provenance.json`. This is shared
  service/domain/storage evidence, without a decoded-video claim.
- The isolated final-wrapper playback candidate passed **21/21, zero skipped**
  in 75.359 seconds on iOS 26.5 Simulator. Its strict real SMB repeated-seek
  case took 32.678 seconds and natural completion took 2.071 seconds. A real
  local SMB provider plus a controlled provider failure at the held 391-byte
  tail published source failure despite typed EOS/input 12.0; the validator
  rejected completion, no `onEnded` fired, and the saved position remained
  below duration. This is a controlled read-failure test, not a claim that an
  external NAS was disconnected. Result/log:
  `.build/NamespacedVLCWrapperProbe/candidate-final21.xcresult` and
  `logs/candidate-final21-test.log`.
- The separate isolated boundary selection passed **9/9** in 19.593 seconds,
  covering paused seek 11.5 persistence without watched, explicit stop,
  session replacement, transport faults, broken media and healthy natural
  completion. Result/log:
  `.build/NamespacedVLCWrapperProbe/candidate-final-faults.xcresult` and
  `logs/candidate-final-faults-test.log`.

These isolated runs used identified wrapper/player copies and a local binary
mirror. Earlier stock-wrapper results below remain historical; neither they
nor independent bridge linking certify the newly combined application.
This record makes no final combined 29-test or new CI pass claim. macOS GUI,
physical-iPhone playback, complete framework rebuilding/relinking and release
distribution retain their separate evidence requirements.

## Planned first-release support

The playback adapter uses the VLCKit-derived backend for MP4/MOV/MKV/AVI,
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
framework for historical stock checks. A temporary local binary target can
reuse an exact identified framework for diagnosis. Final reproducibility/CI
must verify the checked-in specification and the actual modified artifact's
checksum and corresponding source; the stock checksum cannot identify Native5.

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

### Earlier stock-wrapper results

The following results predate the typed bridge and source-health integration
above and do not certify the new combined candidate.

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
