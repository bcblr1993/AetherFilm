# AetherFilm

<img src="Apps/Resources/AetherFilm-icon-v1.png" width="112" alt="AetherFilm icon">

轻一点的私人影院。A native personal video player from [AetherNative](https://www.aethernative.com/).

**[v0.1.0 macOS 已发布](https://github.com/bcblr1993/AetherFilm/releases/tag/v0.1.0)，iOS / iPadOS 验收与分发准备中。** Apple Silicon Mac（macOS 26+）· iOS / iPadOS 26+ · Swift 6 · SwiftUI · Liquid Glass。完整验收状态与已知风险见 [测试矩阵](docs/TEST_MATRIX.md)。

AetherFilm focuses on adding your own media, browsing a compact library, and reliable playback. Inspired by everyday Infuse workflows, it is an independent application and is not affiliated with Firecore.

## First-release scope

The name and macOS-first distribution direction are confirmed. Phase one focuses on local files and SMB NAS playback, controls, subtitles / audio tracks and resume. See [scope decisions](docs/DECISIONS.md).

- Local files and SMB NAS connections with directory browsing and range streaming.
- Continue watching, watched state and naturally ordered next-video playback.
- MP4 / MOV and MKV playback; audio selection; embedded and external subtitles with an explicit supported-format matrix.
- Seeking, playback speed, fullscreen and persistent progress.
- Native macOS and iPhone / iPad layouts with light / dark appearance and accessibility support.

See [product scope](docs/PRODUCT.md), [architecture](docs/ARCHITECTURE.md), [compatibility](docs/COMPATIBILITY.md), [test matrix](docs/TEST_MATRIX.md), and [release gates](docs/RELEASE.md). Distribution and device support are confirmed only after the release matrix passes.

## Project

Shared domain and service modules use Swift Package Manager. Platform app targets use a reproducible XcodeGen specification. Credentials belong in Keychain; watched state and library data stay on the device. No account, analytics, or subscription is planned for v0.1.0.

## Links

- Website: https://www.aethernative.com/
- Source: https://github.com/bcblr1993/AetherFilm
- Issues: https://github.com/bcblr1993/AetherFilm/issues

## License

Original application code in `Apps`, shared services and tools is MIT licensed. The derived player wrapper and vendored headers in [AetherVLCBridge](Packages/AetherVLCBridge/README.md) retain their LGPL-2.1-or-later and per-file notices; the repository's MIT license does not relicense them. VLCKit, AMSMB2 and libsmb2 retain their own licenses.

The bridge includes fixed upstream inputs, an exact patch, dated modification notices and deterministic generators. Its 22 generated source files reproduce the compiled package bytes. The historical callback compilation and strong-link results are recorded in its provenance; macOS releases now target Apple Silicon only. Complete application source and pinned dependency materials are required for rebuilding and relinking a modified static bridge. The final source asset and application relink proof remain release gates; this package verification does not establish an independent full engine rebuild. See [third-party notices](THIRD_PARTY_NOTICES.md), [bridge provenance](Packages/AetherVLCBridge/Provenance/inputs.json) and [corresponding-source evidence](docs/BACKEND_EVIDENCE.md).
