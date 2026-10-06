> v0.1.1 发布推进中：用户于2026-10-06授权发布 NAS 优化版；候选版本0.1.1 / build2，尚未打tag或公开发布。PR #1已推送，CI与当前候选正式分发验收仍需实际完成。

> 2026-10-06 P0 / NAS 优化候选已提交至PR #1，尚未发布。旧 v0.1.0 公开 DMG 的证据不覆盖新改动。真实 NAS 先前跳转失败已有连续通过的单次兼容恢复候选，最终统一源 iOS27 和新建 iOS26.5 模拟器完整回归均68通过 / 0失败 / 1私有NAS跳过，首轮倍速预热失败仍保留，最终 Mac 播放回归被 XCTest 会话连接阻塞，Mac UI 被系统 Automation Mode 认证阻塞，完整物理 iPhone、听音、VoiceOver 和新候选分发验收尚未完成。当前结果见 [TEST_MATRIX.md](TEST_MATRIX.md#2026-10-06-p0-与-nas-浏览优化工作区候选未提交--未发布)。

# Release gates

Target: v0.1.0, macOS-first public distribution; Apple Silicon only and minimum
macOS / iOS 26.0. v0.1.0 macOS release published on GitHub with Developer ID signature,
Apple Notarization Accepted and stapled DMG.

## Release published: 2026-10-06 (v0.1.0)

v0.1.0 macOS release asset `AetherFilm-0.1.0-macos-arm64.dmg` (SHA256 `20b579a6c089828808149f2eb776aa7536d4eb8d7b62859326721e300a02f51f`)
was signed with Developer ID Application: YanNan Chen (5984KQD4D7), notarized via Apple Notary Service
(profile `AetherRoute-Notary`, status Accepted) and stapled. Downloaded artifact was verified with
`shasum -a 256 -c SHA256SUMS.txt` and Gatekeeper assessment `spctl --assess --type open`.
GitHub release `v0.1.0` published with release notes, compatibility scope and explicit iOS distribution state.
The signed iOS Release archive (`build/AetherFilm-iOS.xcarchive`) was built and validated; iOS distribution
proceeds per developer account conditions.

## Current continuation: 2026-10-06 (tests executed 2026-10-05)

On base `375fc63` with the pre-existing SMB cancellation-fixture barrier,
local shared tests actually passed45 with8 opt-in SMB3 skips; separate encrypted
SMB3 passed8/0/0 and AddressSanitizer SMB integration passed4/0/0. All three
platform build-for-testing targets and the development-signed iOS Device build
passed. Original iOS27 and iOS26.5 Simulator playback each passed65/0/0,
with no runtime warnings;26.5 does not certify exact26.0 or a physical device.
Original playback on
the user-approved remote Mac mini (ARM64, macOS27.0.1, Xcode26.5, SDK26.5)
passed57/0/0 with unchanged assertions, deadlines and Main Thread Checker.
The remote182 protected source/fixture hashes match the snapshot; strict signing
verification and owned fixture / Aqua-agent cleanup passed.

Current Phone and Pad full UI each passed18/0/1; the real system Reduce
Transparency case separately passed1/0/0 on each, restoring the original setting.
The first Mac mini UI run could not initialize because automation mode required
administrator authentication; that zero-case failure is retained. The subsequent
original full19 run completed17 passes,1 failure and1 natural Reduce Transparency
skip, exit65. The sole failure is the unfiltered accessibility description audit
of an empty Disabled system TouchBar. An independent minimal native AppKit
window/button control reproduced the same audit failure (0/1/0); a temporary
SwiftUI TouchBar customization also failed and was reverted. Neither diagnostic
waives the original audit. Actual Mac Reduce Transparency and spoken VoiceOver
acceptance remain open; no audit filtering or weakened assertions were applied.

CI37215169426 remains failed, with real shared/Mac/iOS failures and a native
SMB teardown crash in the iOS4K test. Successful local runs do not certify that
intermittent crash fixed, or rewrite the CI result as a quota problem. Current
physical-iPhone full acceptance, user-NAS/listening/spoken VoiceOver, desktop UI,
minimum macOS runtime, final signed/notarized installation and distribution gates
remain open. The user authorized a source push on2026-10-06; release tags and
App publication are outside this continuation. A source push does not close
these release gates.

Evidence: `.build/Continuation20261005/`, especially `MacMiniPlayback-r2/`,
`MacMiniUI-r1/`, `MacMiniUI-r2/`, `MacMiniUI-native-control-r1/`,
`MacMiniUI-audit-touchbar-r1/`, `iOS-Full-r1.xcresult`, `iOS26-Full-r1.xcresult`, the four Phone/Pad UI bundles,
`SMB3-r1.json` and retained validation logs. Exact counts and limitations are in
`TEST_MATRIX.md`.

## Historical candidate notes: 2026-10-04

The unified Native8 candidate now contains four additional tail regressions;
the original61 iOS /53 Mac assertions and deadlines remain unchanged. Its pure
three-platform native build, six wrapper targets and three-slice assembly passed.
The private final C4 candidate passed physical original3/0/0 and new4/0/0;
eight actual drain-to-stop windows contained no later valid native clock point.
Final unfiltered iOS65 /Mac57, complete UI, signed installation, App publication
and website deployment still require their own evidence.

Preceding source `6100c1c` passed CI37202599510: all three ARM64 platform builds,
Mac26 playback53/0/0 and iOS27 Simulator playback61/0/0. Independent xcresult,
raw-log and expected-case identities agree. Shared tests actually executed
45 passes with8 opt-in SMB3 skips; the five runner unit tests passed. The
separate real encrypted SMB3 gate remains8/0/0. Earlier CI failures are retained.
The split native SwiftUI expressions resolve the SDK26 typechecking failure;
progress saves now join the existing ordered persistence queue before flush.

Public Native7 still has two physical iPhone tail-seek failures (full61:59/2/0).
A private native correction converts only media preroll to system ticks and
preserves caching compensation. It passed the original three physical regression
cases,3/0/0, including half-speed, without changing their assertions or deadlines.
The two new short-GOP tail controls actually returned1/1/0: at2× the last
normal clock11.771539 was below the unchanged new11.8 threshold. The same
short-GOP controls passed2/0/0 on known Native7, so they do not reject the
original long-GOP defect. Independent long-GOP coverage and actual audio drain
are being checked; the short-GOP failure is retained.
The additional AV async-drain candidate passed original3/0/0. Four new
controls returned2/2/0, then3/1/0 after the first upper-bound revision;
the2× long-GOP normal clock12.286767 still exceeded12.26. The real renderer
consumed every queued sample. Independent raw callbacks show that the public
normal clock uses a planned system-time/rate anchor and can lead the physical
sample position; observer period plus filter stride does not establish a
nominal-duration upper bound. A still-unmerged control revision will bound
clock progress by the independently measured monotonic elapsed seek time,
preserving all original61 assertions, fresh callback/output gates, tail lower
bounds, six-second deadline and exactly-once completion. Known Native7 was
correctly rejected by both same-source long-GOP controls,0/2/0. All original
failure records remain. This private numeric diagnostic build is not a
production component; no native completion fix or App release is certified yet.

Native7 fullUI binds preceding source `987ce91`: Phone and Pad18/0/1 each,
Mac17/1/1; actual system Reduce Transparency separately passed1/0/0 on all
three targets with original settings restored. The sole Mac failure is the
unfiltered system Disabled empty TouchBar description audit; no exception is
granted. Final unified-source UI acceptance remains open. User-NAS, audible and
spoken VoiceOver acceptance remain open; exact scope is in `TEST_MATRIX.md`.

The Native7 binary and corresponding source are public in a separate technical
prerelease, with complete anonymous downloads matching length and SHA256.
A full fresh portable source rebuild has not executed. The signed/notarized
Mac candidate and development iOS archive bind `987ce91`, not current source;
new final builds, installed VM / physical-device Release playback, public App
download and website deployment remain open. Host Gatekeeper has a pre-existing
security override and cannot replace Gatekeeper-enabled VM acceptance.

Evidence: `.build/Native7CICommit6100c1cReview20261004-r1/`,
`.build/NativeBufferingPrerollRateActualReadonly20261004-r1/REPORT.json`,
`.build/NativeCoreAudioClockCadenceMobileAcceptance20261004-r1/`, and the
UI / distribution evidence paths in `TEST_MATRIX.md`.

## Historical candidate evidence

2026-10-04 authentication continuation: after the user authenticated UI automation inside the macos27 VM, the same narrow UI candidate passed the actual Reduce Transparency case with1 pass /0 failures /0 skips, exit0. The original absent preference key and false API state were restored. Both earlier runner-initialization timeouts remain retained. This does not replace acceptance of the final unified Native6 source. Evidence: `.build/NativeSMBAXTypeUIExecution20261004-r2/MacReduceReview-r3/`.

Target: v0.1.0. No release has been published.

Latest final combined-source execution (2026-10-04): Native6 r2 SOURCE_READY35707893 passed the original unfiltered full61 on both iOS27 and the owned iOS26.5 Simulator,61/0/0 each, exit0, with original checker dictionaries, strict seals, complete source/product/config/cache guards and original deadlines preserved. The owned26.5 was actually restored to Shutdown. The additional real-SMB control also passed explicit disktrue at qualified output95% → same pending391-byte source failure → diskfalse with valid resume; native stopping reason1 is retained and rejected by the application validator. Mac53/UI19, physical iPhone, Mac26 and distribution still require their own final evidence. Earlier qualification and runtime failures remain preserved. Exact results are at the top of `TEST_MATRIX.md`.

Independent fixes in progress (2026-10-04): the real audio-renderer100ms clock candidate passed the unchanged half-speed function case1/1, with EOS24.568336 seconds, final normal12.072098, real audio/video output and exactly one completion; the original30-second bound and tail assertions remain. The session-owned watched-state correction separately passed10 focused cases on each of iOS26.5 and27. Those original fault runs did not cross an automatic95% checkpoint before failing, so an additional strict SMB integration control is still required to certify that rollback path. The original unified failures below remain preserved, and full combined-source, device and distribution acceptance are still open. See `TEST_MATRIX.md` for the exact artifacts and limitations.

Current narrow UI evidence: the final identifier/native-value and expanded-sheet-height correction passed the original SMB case on all three targets. The unfiltered full19 is17/1/1 on Mac (only the system TouchBar audit fails), and18/0/1 on each mobile simulator. Real system Reduce Transparency separately passed1/1 on both mobile targets with settings restored. The same corrected Mac products encountered two automation-mode initialization timeouts before entering that case; settings were restored and both original infrastructure failures remain. Earlier Native5 Reduce1/1 evidence is retained as history. No final combined-source UI pass or audit waiver is claimed.

The new natural SMB rollback control on iOS26.5 failed its unchanged30-second healthy precondition before fault injection: a genuinely held391-byte tail stopped input at10.43091, below95%, despite the advancing renderer clock. Source/products/checker/signatures and owned simulator restoration passed. This is not rollback-path acceptance; a reachable real-playback control is being prepared without changing the original54 or six persistence controls.

Minimum-system branch evidence (2026-10-04): the same sealed Native5 App passed the complete54 cases on the owned iOS26.5 simulator, zero failures/skips, exit0, with exact source/products/configuration/cache and strict signatures. Its initial Shutdown state was restored. This certifies this simulator/runtime run, not iOS26.0, physical iPhone or macOS26, and does not waive the two actual iOS27 failures below. Evidence: `.build/FinalNative5SimulatorAcceptance20261004-r1/Results-iOS26.5-full54-r1/outcome.json`, SHA `21ce554a…`.

Current combined-source gate (2026-10-04): the final Native5 iOS27 unfiltered54 run actually passed52, failed2 and skipped0, exit65. The exact compiled/runtime case list, original source/products/configuration/cache and strict signatures remained stable. Half-speed EOS arrived within the original timing bounds, but its last normal media clock was11.568169 against the unchanged11.9 tail assertion. A real tail read fault also exposed a previously automatic95% watched mark that was not revoked; existing/manual watched controls passed. Both failures are retained and block release. The earlier independent53/53 and half-speed1/1 results do not certify this combined candidate. Evidence: `.build/FinalNative5SimulatorAcceptance20261004-r1/Results-iOS27-full54-r2/outcome.json`, SHA `9fa71eb6…`.

Current architecture scope (user confirmation, 2026-10-04): macOS releases require Apple Silicon (arm64) and macOS26+. Intel compatibility, Intel builds and universal-Mac packaging are removed from current release gates. Build the App and embedded frameworks for arm64; the DMG is named `AetherFilm-0.1.0-macos-arm64.dmg`. Historical universal-build evidence below remains historical. iOS / iPadOS minimum26 and physical-device acceptance remain required.

Baseline frozen Native4 evidence (2026-10-04): the three ARM64/min26 framework slices and all three App builds passed their build and strict signing checks. Physical iPhone12Pro/iOS27 playback50 was49 passes/1 failure/0 skips; simulator playback50 was48/2/0; Mac playback42 was41/1/0. All physical SMB cases and 4K hardware evidence executed. The waiting-UI fixture allowed its original seek0 target to recover, and the simulator also failed its saved-watched assertion. Mac UI19 was16/2/1, with SMB disclosure interaction and an empty disabled system TouchBar audit issue failing. These original results remain preserved; the corrected combined App requires fresh acceptance. See `TEST_MATRIX.md` for artifacts and precise limitations.

Independent candidate evidence (2026-10-04): the hidden-control view-tree correction passed the unchanged full UI19 on both iPhone and iPad simulators (18 passes / zero failures / one natural skip each), plus a real system Reduce Transparency check on each device with settings restored. The qualified unread seek8 target and confirmed-progress correction passed all53 iOS27 playback cases, including real healthy pre-EOS95% confirmation and preservation of prior/manual watched records. These exact tested source changes are merged. The Native4 four-container smoke passed on an owned iOS26.5 simulator; full minimum-system and combined-source regression remain required. The first SMB identifier-only correction failed its unchanged case during exclusive execution; a native label-click correction is awaiting the user's shared-VM test window.

The half-speed audio timing correction is built into all three Native5 framework slices. Its new functional case actually passed1/1 with zero failures or skips: the12-second clip reached EOS around24.57 seconds,22.056 seconds after early real output readiness, within the independent30-second bound and above the21.202-second lower bound. Real tail audio/video, normal/input time, engine identity and exactly one completion were checked. The test is merged without changing the original53 cases or deadlines; the older60-second measurement is retained separately. Final Native5 playback54 /46, full UI, physical device, distribution and public-download acceptance are pending. The macOS26 CI job is configured and five local runner failure/control tests pass; hosted build/runtime has not executed. The pinned synthetic EOF asset pair preserves byte-range qualification across encoder versions. No App release or gate waiver is claimed.

Latest physical-device execution (2026-10-04): the original native3 unfiltered50 run on the USB iPhone12Pro / iOS27 was39 passes /1 failure /10 SMB bootstrap skips. The four original local seek cases passed. The sole 4K failure was subsequently matched with a precise static-log recognition correction; the unchanged original 4K case passed1/1, exit0, with VideoToolbox selected/accepted-frame evidence and real video/audio output. Strict signatures and source/product guards passed before and after that run. The first full result remains preserved; physical SMB, full UI, audible acceptance, minimum26 runtime and distribution still require evidence. The fixed-cache native IO mechanism control passed24/24 primary expected outcomes and all13 candidate controls, but its no-drain negative hypothesis was disproved and the original runner exit1 is retained. That C correction is not yet built into the App and does not establish recovery of the original App's intermittent held-tail failure. See `TEST_MATRIX.md` for the exact artifacts and limitations.

Latest execution (2026-10-04): the iOS27 ARM64 native3 candidate passed the original four seek cases, including actual new paused preview, with4 passes /0 failures /0 skips. The same sealed App's first unfiltered50-case playback run was49 passes /1 failure /0 skips (formal44 mapping43/1); held-tail seek0 failed its original6-second output gate. Two later single-case runs and one unfiltered50-case run passed, but all three passive samples were NO_STALL / INCONCLUSIVE with different HTTP/cache history; the original failure remains open. The Mac27 VM unfiltered UI19 was11 passes /7 failures /1 natural Reduce Transparency skip; raw logs identify Apex UI interference in four failing cases, separate audit/AX timeouts remain, and exclusive UI acceptance is still required. The corrected native SMB-control click has a newly compiled and signed UI19 product with unchanged App bytes; it has not yet run in the VM. The iPhone baseline core compilation and nm both exited0, with6269 native ARM64/platform2/minimum≤26 members and302 defined modules. The three pause corrections subsequently passed all14 Device object/archive steps, preserving the other6266 full-archive members and839 protected inputs. Both Device wrapper targets then exited0; the actual52874192-byte framework is arm64/platform2/minimum26/SDK27, with302 defined modules, unchanged primary inputs and retained warnings. Signed App and physical-device acceptance remain required. Evidence and precise scope are recorded at the top of `TEST_MATRIX.md`. No release or distribution gate is waived.

Latest isolated Mac paused-preview candidate (2026-10-03): the three native corrections together passed all four original seek-status cases, with0 failures and0 skips. Original assertions, fixtures and6-second deadlines were unchanged. The actual paused seek to8 produced a new input at7.997333 and normal video-clock event at7.966667 with new displayed frames before clearing the UI; an earlier readonly getter at the target did not clear it. Subsequent samples remained paused. Playing rapid seeks and stop/change also passed. All eight object/archive stages and both actual wrapper targets exited0, with raw MTC/background-layer/fixed GL counts0. Root checked the actual execution, original inventories and specific output evidence; independent review additionally read all eight trace/UI attachments in full. Evidence: `.build/SeekPausedPreviewDecoderMacProductsCandidate20261003/Results-mac-strict4-r1/` and `.build/SeekPausedPreviewDecoderMacRuntimeReview20261003/`. This is a Mac27 ARM64 diagnostic result; all paused interleavings, iOS, final App/full UI, minimum26 and distribution remain open. Earlier paused failures and formal36/36,43/1 evidence are retained.

Current formal-source verification (2026-10-03): the same frozen source built both test platforms. The complete Mac run passed36/36 with no failed or skipped cases; the iOS27 run passed43/44 with one active seek0 failure under indefinitely held tail IO and no skips. Exact case lists and unchanged source/product inventories were independently verified in `.build/FormalVerificationFinal36-44IndependentReview/`. Mac retained the original Main Thread Checker settings; its raw log had no fixed MTC / background NSView.layer / OpenGL assertion prints. A matched start2 complete-source seek0 control passed1/1 with real new video/audio and both clock/input rewinds; it does not replace the failing held-source test. The formal SMB3 encrypted group passed8/8 and default shared tests passed45 with8 opt-in skips. These results do not replace real NAS or physical-device acceptance.

The native sample-buffer backend is integrated in formal source. Historical normal Mac windows for ASS / SRT / VTT showed readable Chinese at the first cue, next cue and after a real seek, while missing H.264 clean aperture caused narrow side bars. An isolated aperture patch passed helper tests and the actual Mac arm64 core build. The third wrapper attempt built both targets with exit0; original tool-reader and deployment-target failures remain retained. Its owned-window H.264 / ASS diagnostic then exited0:124 public CM formats had valid320×180 aperture within coded320×192, VT reported hardware=1, and Root reviewed three original PNGs with correct cues and full16:9 picture without the old side bars. Original phase deadlines and complete raw logs were retained. A separate actual rebuild of18 GSM objects and static remerge passed;6544 other objects remain byte identical and all6562 minimum targets are≤26. The corrected archive then passed both fourth-wrapper targets and another real H.264 / ASS three-stage visual run, with Root-reviewed picture/glyphs and hardware=1. These are Mac27 diagnostic results, not final App, all orientations,4K or minimum26 runtime acceptance. App targets remain26. The earlier isolated seek-status candidate built both platforms but failed both paused-preview UI cases on each; rapid seeks and stop/change passed. The latest Mac-only native candidate result is recorded above. Its single new formal held-source control passed with real output, without a core recovery fix, and does not cancel the historical full-suite failure. Full Mac UI products await manual VM Aqua login. The unfiltered accessibility audit retains the empty system TouchBar failure and native baseline reproduction; the rejected filter was not applied. Physical iPhone acceptance, current-source signed package, release tag, public download and website deployment remain open. See `TEST_MATRIX.md` for exact evidence and original failures.

The corrected-archive diagnostic also passed real H.264 / SRT and WebVTT three-stage runs; Root and an independent review checked all six original PNGs for Chinese glyphs, full16:9 picture and first/next/rewound cues. Together with ASS, the current diagnostic has nine reviewed screenshots. A separate readonly public-core-time probe preserved both paused tests and their6-second deadlines: both platforms still failed both cases, and the getter remained at pre-seek time. Display statistics alone do not establish a target preview, so this query has not been used to clear the UI or waive the failures. These diagnostics remain separate from final App and distribution acceptance.

The iOS Simulator arm64 aperture core compiled with exit0 and produced6266 native objects with platform7 and minimum versions≤26; all302 generated module entries are defined. Its original driver exited1 on changed build inputs and retains `coreBuildPassed=false`. A separate full5840-input review closed only two differences: Git-index stat caches and the regenerated rav1e vendor container, with identical index semantics,33827 vendor file payloads/order and all other protected inputs. Both actual wrapper targets subsequently exited0. Independent review verified the arm64/platform7/minimum26 framework,302 generated definitions, public APIs, and unchanged source/product inventories. Raw compiler warnings and the missing bundle resource seal remain recorded; a newly sealed App copy is required for runtime testing. These build results do not establish App playback, iPhone operation or distribution.

The corrected-archive 4K HEVC diagnostic now passed three real ASS / SRT / WebVTT runs. Root personally reviewed all nine original own-window PNGs for readable Chinese, full16:9 content and first / next / actually rewound cues. Public CM formats were121 / 121 / 110, all with valid3840×2160 aperture and PAR1:1; all observed hvc1 sessions reported hardware=1. The original phase deadlines and unfiltered raw logs remain. The new copy used standard native signing; the old driver, signing pilot and kernel-rejected launch remain failed and retained. Evidence is in `.build/NativeAperture4KStandardSealedRuntime-r5/` and `.build/NativeAperture4KRootReview20261003/`; an independent review of all nine images and actual execution passed in `.build/NativeAperture4KStandardExecutionIndependentReview20261003/`. This does not establish final App, EOS, all orientations, audible, minimum26 or physical-device acceptance.

The iOS aperture engine has also run in a fresh ARM64 diagnostic product copy: all18 default signatures and strict checks passed without non-signature code/data/UUID changes. Its original complete44 tests actually passed43, failed1 and skipped0 on the assigned iOS27 simulator, exit65. The same indefinitely held-tail seek case still had no new video/audio over the original6-second observation. All original compiled inputs/products and checker configuration remained unchanged; raw MTC/background-layer/GL prints were0. This engine does not contain the native pause candidate. Evidence is in `.build/NativeIOSSimulatorAppIntegration20261003-r3/`; the old reserve failure remains unchanged. Final engines, subtitle visual checks, minimum26, physical-device and release acceptance remain open.

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

2026-10-03: the production implementation baseline is `e4d7ff0f8e91e99cec13c6bca66c60dda795ad3a`, including the derived typed-callback bridge, confirmed progress, source-health completion validation and session isolation. Commit `fb65037810a241b35b5e09c9e4b9f71a84a0e008` contains two TCP test-helper corrections and documentation. The current diagnostic changes add bounded DEBUG timelines, failure attachments, four shared diagnostic-boundary tests and explicit ARC ownership for Mac test windows; they do not change release playback, protocol deadlines or the agreed scope. Mac UI query/layout corrections are being validated separately. No current-source signed macOS DMG has been prepared.

The formal iOS 26.5 application run passed **29/29, zero failures or skips**, including AppStore 8, audio preparation/coordinator 8, EOF 4 and original playback 9. Result: `.build/results/AetherFilm-final-bridge-full-20261003-0038.xcresult`. Natural completion retained its original 6-second deadline, pause drift retained 0.35 seconds, and all 20 SMB seek/output assertions were preserved. The same App completed the full UI run with **18 passed, zero failed, one opt-in skipped**; a correctly configured Reduce Transparency run separately passed **1/1, zero skips**. Together, 19 scenarios actually ran; 22 original screenshots were reviewed and all 69 installed App files matched the build. Evidence: `.build/FinalBridgeUIEvidence/review.json`, full `0040` and dedicated `0047-v2` xcresults. The incorrect legacy target/configuration skip in `0045` remains preserved. This does not certify full-app maximum text sizes or spoken VoiceOver acceptance.

GitHub run `37083136280` for `e4d7ff0` **failed overall**. Its platform job passed all three builds and the formal iOS 27 Simulator **29/29, zero failures or skips**, with no runtime warnings. Its shared job was **34/41, seven failures, zero skips**: six BSD socket receive EAGAIN errors and one concurrent stalled-protocol check at 8.162 seconds against the unchanged 5-second deadline. Exact logs/artifact and review remain in `.build/CIe4d7ff0Evidence/review.json`. A green platform job does not satisfy the CI gate.

Two test socket helpers now execute blocking BSD operations on dedicated concurrent GCD queues through continuations instead of detached Swift tasks. The full local shared suite passed **41/41, zero failures or skips**: Domain 9, Library 4, Sources 28. All assertions, the existing 3-second socket receive timeout and the 5-second stalled-protocol limit remain unchanged; no filtering or serialization was added. Evidence: `.build/SMBSocketQueueFixEvidence/review.json`. The blocked cooperative-executor path is established, but no CI thread trace proves it is the sole cause of the earlier delays.

GitHub run `37084529322` for `fb65037810a241b35b5e09c9e4b9f71a84a0e008` **failed overall**. Shared tests passed **41/41**, and all three platform builds passed. The iOS 27 Simulator application tests were **26/29, three failed cases, zero skips**: the two real-SMB near-tail cases timed out before actual output reached their gates, and the repeated-seek case timed out on its first seek. Six failure records belong to these three cases. Exact artifact `11260201844` and review remain in `.build/CITestSocketFixEvidence/review.json`. The same unchanged test product passed the three focused cases locally on iOS 26.5 in **38.298 seconds**, with its source and binaries checked before and after; `.build/PlaybackEvidence/CI-fb650-Focused3/review.json`. This does not replace the failing iOS 27 CI result. Bounded, explicitly enabled DEBUG numeric timelines are being added to distinguish data delivery, decoder callbacks and application state; no playback deadline or output assertion is relaxed.

Diagnostic run `37086982680` for `4d25379ea11cb7caf2122ccd15c62ac889b1be82` also **failed overall**. Shared compilation failed before execution on Xcode 26.6 / Swift 6.3.3 because a DEBUG Task initializer was ambiguous. Platform builds passed; playback was **27/29, two EOF readiness failures, zero skips**. All 20 SMB seeks and reopening passed this run. Exact artifact `11261102382` matched its digest; `.build/CI4d25379Evidence/review.json` preserves the original result. Recorded delegate delivery and HTTP-send completion were short; opening/source reads consumed seconds before normal clocks began. The traces do not establish a particular SMB/C-lock root cause, and neither EOF test reached tail release/failure injection or completion validation. An explicit `Task<Void, Never>` fixes the compile ambiguity locally; Swift 6.3 CI verification is still required. The same diagnostic product passed the full local official iOS 27 run **29/29** in 82.917 seconds; this does not replace CI.

EOF test phases now give cold opening its existing 12-second actual-output gate before the unchanged six-second held-tail seek/output gate. A separate real-SMB cold-resume case retains direct `startAt: 10` coverage and real clock/input/frame/audio evidence before natural EOS. Its first observed running clock with real video/audio must be at least 9.95 seconds, rejecting ordinary playback from zero; the original readiness and EOS deadlines remain. Dynamically selected tail bytes remain withheld until the original gate passes, and video/audio after the explicit seek must each increase by more than five from its pre-seek baseline. Independent static review is in `.build/SMBDebugTraceEvidence/PhaseReview/review.json`; the earlier 30/30 draft lacking the first-output guard is not final evidence. The strengthened iOS 27 full suite passed **30/30, zero failures or skips**, in 78.575 seconds; the three SMB EOF cases passed **3/3** on iOS 26.5. A separate test-only negative copy using startAt0 was correctly rejected at clock0.866667 after 2.051 seconds. Original xcresult summaries are in `.build/PlaybackEvidence/PhaseGuard/`. This changes test setup, not production timing or streaming.

Exact commit `3210ab28466b4ba0cb0f109e587892e048002be4`, GitHub run `37089277731` attempt1, **passed overall**. Shared tests were **45/45, zero failures or skips** on Xcode26.6 / Swift6.3.3, verifying the explicit DEBUG Task type. All three platform builds passed; the formal iOS27 / 24A434 application run was **30/30, zero failures or skips**, 163.280 case seconds / 163.429 suite seconds. Real SMB completed all20 seeks and reopening. Artifact `11262016795` matched official SHA256 `2375c339e54aa1dc3e00754d73edda79ecd9437ac7c2dd975faa8d7c75eb6e60`; original results, attachments and logs are in `.build/CI3210ab2Evidence/review.json`. xcresult runtime warnings were empty, but the console contained audio-system warnings. This CI result does not certify Mac graphical playback, physical iPhone operation or distribution.

The enhanced Mac22 suite ran in the existing Aqua session with the original output assertions and deadlines: **10 passed, 12 failed, zero skipped**, 181.378 seconds. Failing output gates had decoded/displayed video0/0 while audio and clock could advance. The earlier ARC/window-close crashes did not recur; this does not establish the black-screen cause. Original result, numeric failure attachments and Aqua context are retained in `.build/ReleaseEvidence/candidate-fb650378/GUIReadiness-native-ui-c4fd83c4/PhaseGuard22/Results-AquaPlayback22-20261003-c4fd83c4/`. Mac playback remains a failing release gate. Separate stock/derived default-player diagnostics both recorded OpenGL view initialization failure. An independent experiment with the fixed engine’s original pixel-format attributes returned nil before view creation; the alternate CA output also failed to open. Original numeric records are in `.build/NativeMacUIDiagnostic-c4fd83c4/GLCA/Results-Aqua-20261003-c4fd83c4/`. These results locate the VM failure stage; they do not establish real-Mac compatibility. The four-variant renderer experiment confirmed an online software renderer in the VM: Accelerated requests fail, whereas software format/context/view creation succeeds. No production backend was changed. The separate real-Mac22 run was **17 passed, five failed, zero skipped**: two unchanged held-tail clock gates and three SIGABRT OpenGL framebuffer assertions (Replay,4K,CommonContainers). Real H264 output, cold SMB10 and all20 SMB seeks/reopening ran successfully; they do not replace the failing full run. Exact result and independent review are in `.build/HostMacPlayback22-06009614/`. Independent stock/derived processes are being prepared to isolate output and host-window lifecycle; physical iPhone and final distribution remain open.

Current-source macOS Debug/test products, unsigned arm64+x86_64 Release and the iOS Release archive were built. The new iOS archive passed **57/57** independent content/signature checks: minimum 26.0, iPhone/iPad, three arm64 Mach-O files, actual signature/provisioning, icons, four license texts plus bridge source/third-party notices, no test bundles or fixtures, and the derived class/callback evidence with no diagnostic getter. All 68 compiled-source/resource hashes matched the formal and frozen project. Evidence: `.build/ReleaseEvidence/ios-archive-inspection-confirmed-eof-system-trust.json`. The initial sandbox trust errors are retained; read-only system-trust verification passed outside the sandbox. This is an **Apple Development archive with `get-task-allow=true`**, not a TestFlight/public-distribution export, and it has not been installed or launched on the real iPhone.

An exact-`e4d7ff0` complete application/bridge source candidate, its manifest and archive, and actual modified-wrapper relinking are verified in `.build/CorrespondingSourceCandidates/e4d7ff0-51b82e86/{stage-review.json,relink-review.json,archive-review.json}`. Baseline and modified universal macOS Apps were relinked for arm64 and x86_64: both modified slices contained the marker, both baseline slices did not, and minimum macOS remained 26.0. A CLI consumer returned the one-file bridge modification's marker. No iOS relink or App GUI was executed. This does not establish a full libVLC engine rebuild or App GUI/playback acceptance. The candidate is unpublished; the final commit requires a new independent source archive and explicit hash binding to unchanged production code and the actual distribution build.

The DMG currently on disk belongs to old `c790607`; the 54 Gatekeeper-enabled VM checks belong only to old `5e12be2`. Neither certifies the new bridge. A new signed/notarized DMG, its VM install/first-launch/playback and published download checks remain open. The Mac VM now has an existing Aqua session. Running UI tests through that session produced **11 passed, seven failed, one opt-in skipped** in 204.137 seconds; original results and screenshots are retained in `.build/ReleaseEvidence/candidate-fb650378/GUIReadiness-native-ui-c4fd83c4/Results-AquaUI-20261003-c4fd83c4/`. The failures cover accessibility description, narrow-window sizing, return from full screen, system picker querying, playback advancement/controls and the SMB form. The earlier SSH-context UI initialization timeout is separate. The SSH-context Mac application run was **8/21 passed, 13 failed**; video output was absent and the crash logs showed an ARC/window-close problem in the test harness. New test windows retain ownership on close; the subsequent Aqua22 run above did not crash but still failed actual video output. The VM has a real1920×1080 display; an empty SSH display report did not establish that a display was missing. No account, automatic-login or security setting was changed. The physical iPhone is still locked, and no tag, release, TestFlight/public iOS installation or website deployment has completed. Remaining device/UI boundaries are recorded in `TEST_MATRIX.md`.

## Historical candidate evidence

2026-10-03: the preceding signed DMG is built from `c7906074451b0a8ccb0b5ad6f7f462f3ea60f4c1`. It includes TCP half-close compatibility, reconciliation of a reproduced late-pause control-state defect, and synchronous iOS audio activation on a background serial coordinator. Both platform Debug test products, universal macOS Release and an iOS Release archive were built. A local iOS 26.5 run passed 22/22 playback/AppStore/audio cases and a separate focused UI run passed 3/3. Historical complete UI results remain valid only for the source and scenarios recorded in `TEST_MATRIX.md`.

GitHub run `37075306804` passed shared tests 33/33 and all three builds, but platform tests were 21/22: natural completion after a seek failed when the wrapper's cached time rolled back from 11 to 6.179 seconds before stopping. Twenty real SMB seeks and all audio lifecycle cases passed this round; the slowest seek still approached the unchanged 12-second deadline. The complete logs contained no AudioHangRisk text and no xcresult runtime warnings. These observations do not prove SMB stability or the underlying completion cause. Evidence and earlier failed runs are retained; this is a failing release gate.

The old c790607 App and DMG notarization are Accepted; signatures and tickets validate. DMG SHA256 is `84c488982fb76402d8d47515b155de46e6b6d5c9f8b3350056f2cdac5ba4d684`; 31 local inspection checks passed, including the read-only mounted volume, licenses, icon, minimum 26.0, universal Mach-O files, and UUIDs matching the built app. `artifacts/CANDIDATE_MANIFEST.json` records three asset hashes and `publicationReady=false`. Host policy assessment is limited by its pre-existing security override. The 54 Gatekeeper-enabled VM checks and relocated Debug products belong to the preceding `5e12be2` / `fb32d110` candidate, retained in `artifacts/previous-candidates/0.1.0-fb32d110/`; they do not certify c790607 or the current-source candidate. The VM remains at its login window and no GUI first-launch/playback or UI acceptance has run.

The old c790607 iOS archive passed 32 signature/file inspections with minimum 26.0, iPhone/iPad support, arm64, icon and licenses, and no test bundles/fixtures. It is signed with Apple Development and `get-task-allow=true`, not an App Store/TestFlight distribution export. It has not been installed on the locked real iPhone.

Subsequent settings fixes show visible native subtitles-size and volume captions. The DEBUG UI appearance helper now preserves the system font unless an explicit test override is supplied. Four targeted runs passed: settings, native slider adjustments at the standard system size, actual accessibility-extra-large, and the maximum system size with no override. Original screenshots and app/dylib byte identity are recorded in `.build/UILabelEvidence/review.json`. Earlier controlled-font results were reclassified without deleting their evidence. The old signed DMG predates these settings fixes; current source builds and UI results are recorded above, while packaging and exact-candidate acceptance remain open.

No tag, release, public download or website deployment has been completed. Core CI, macOS graphical acceptance, iPhone playback acceptance, full-app maximum typography/VoiceOver and the remaining compatibility matrix are open. The isolated website candidate has passed checks and browser review but remains unpublished. See `TEST_MATRIX.md` for exact evidence and limitations.


原生 sample-buffer 候选已通过 ASS / SRT / VTT 共九张正常字幕画面的 Root 复核及 H.264 硬件属性检查；跨显示队列片尾候选在 iOS 两项真实 SMB golden 加十项纯判定实际12/12。从真实2秒段回零的held负向和完整SMB来源回零控制各实际1/1。现已合入正式源码并成功构建Mac36 / iOS44测试产品，完整回归待执行。4K初始字幕和hardware=1有正常窗口证据；独立作者样式的ScaledBorderAndShadow=yes实际清晰，不代表引擎修复。H.264物理比例、原早期seek0在held条件下恢复、完整新UI、设备与分发验收仍待完成；无tag或公开版本。


最新正式完整回归为Mac36/36、iOS43通过/1失败/0跳过；Mac原MTC环境保留、原始固定MTC/GL打印0。当前H.264原生格式缺visible aperture，实际320×180被呈现为320×192，正常图像窄黑边仍为失败项。M1健康放行单项虽1/1，但放行前已在播放缓存，没有复现旧stall，不证明其修复。完整UI、物理设备和新分发包仍待验收，不发布tag或版本。
