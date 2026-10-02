# AetherFilm

轻一点的私人影院。A native personal video player from [AetherNative](https://www.aethernative.com/).

**规划 / 开发中，尚未发布。** macOS 26+ · iOS / iPadOS 26+ · Swift 6 · SwiftUI · Liquid Glass.

AetherFilm focuses on adding your own media, browsing a compact library, and reliable playback. Inspired by everyday Infuse workflows, it is an independent application and is not affiliated with Firecore.

## First-release scope

The name and macOS-first distribution direction are confirmed. Phase one focuses on local files and SMB NAS playback, controls, subtitles / audio tracks and resume. See [scope decisions](docs/DECISIONS.md).

- Local files and SMB NAS connections with directory browsing and range streaming.
- Continue watching, watched state and naturally ordered next-video playback.
- MP4 / MOV and MKV playback; audio selection; embedded and external subtitles with an explicit supported-format matrix.
- Seeking, playback speed, fullscreen and persistent progress.
- Native macOS and iPhone / iPad layouts with light / dark appearance and accessibility support.

See [product scope](docs/PRODUCT.md), [architecture](docs/ARCHITECTURE.md), [test matrix](docs/TEST_MATRIX.md), and [release gates](docs/RELEASE.md). Features above are in development; support is confirmed only after the release matrix passes.

## Project

Shared domain and service modules use Swift Package Manager. Platform app targets use a reproducible XcodeGen specification. Credentials belong in Keychain; watched state and library data stay on the device. No account, analytics, or subscription is planned for v0.1.0.

## Links

- Website: https://www.aethernative.com/
- Source: https://github.com/bcblr1993/AetherFilm
- Issues: https://github.com/bcblr1993/AetherFilm/issues

## License

Application code is MIT licensed. Any bundled media framework is distributed under its own license; see `THIRD_PARTY_NOTICES.md` when the playback dependency is integrated.
