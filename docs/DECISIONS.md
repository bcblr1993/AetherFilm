# Scope decisions

Updated: 2026-10-02 (Asia/Shanghai).

## Confirmed by the user

- Product name: AetherFilm, aligned with AetherNative.
- Native macOS 26+ and iOS 26+; native system glass design.
- Public GitHub repository direction; macOS v0.1.0 downloadable release first.
- iOS build and testing alongside macOS, with TestFlight / App Store distribution advanced according to the developer account conditions.
- Show Infuse's feature inventory first, then let the user select phase-one features.
- Phase-one features: **1, 2, 3, 4, 5, 9**. Primary source: **SMB NAS**. These cover playback, controls, subtitles / audio, local files, SMB browsing, progress / resume and next video.
- The user explicitly requires a polished UI experience and an attractive app icon.

## Scope boundaries

- Local files and SMB are the first release's source adapters. WebDAV, NFS / FTP and Jellyfin / Emby / Plex are subsequent source work.
- Metadata matching, a complex poster library, offline download, cross-device sync, PiP / casting and advanced formats outside the common playback matrix are not selected for phase one.
- Do not require a poster library to make the UI polished: clear navigation, good file rows, useful progress, native controls and responsive layouts are the selected flow.

The user's feature-number selection supersedes earlier recommendations. Application implementation is now authorized within this scope. App icons use original artwork; no Infuse branding or assets are copied.

## Evidence and remaining checks

- The workspace is being bootstrapped with shared domain / persistence / SMB services and native platform targets. Builds and published artifacts must be checked before claiming availability.
- Xcode 27.0 / build 27A266a and macOS / iPhoneOS SDK 27.0 are installed.
- The installed SwiftUI public interface annotates `GlassProminentButtonStyle` with macOS 26.0 and iOS 26.0 availability; the glass design does not require raising the requested minimum versions.
- AVFoundation / VLCKit remain backend candidates, not tested application support. A framework's format list does not prove this application's decode, subtitle, hardware acceleration, PiP or AirPlay behavior.
- Real device and signing checks must run in an environment with access to the device service / Keychain. A sandbox result of no identities or CoreDevice initialization timeout is inconclusive, not proof that the user lacks certificates or a connected iPhone.

## Primary references

- Infuse features and technical specifications: https://firecore.com/infuse
- Apple Liquid Glass: https://developer.apple.com/documentation/SwiftUI/Applying-Liquid-Glass-to-custom-views
- Official VideoLAN VLCKit mirror: https://github.com/videolan/vlckit
- Jellyfin codec negotiation: https://jellyfin.org/docs/general/clients/codec-support/
