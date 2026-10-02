# Architecture

## Principles

Native apps, shared domain, explicit side effects, small modules. Swift 6 strict concurrency. Services accept injectable transports / stores so protocol and persistence tests do not require production servers. Views never perform credential or protocol operations directly.

```text
Apps/
  Shared/          App entry, observable state and shared SwiftUI views
  macOS/           Platform configuration, entitlements and resources
  iOS/             Platform configuration and resources
Packages/AetherFilmKit/
  Sources/
    FilmDomain/    MediaItem, MediaSource, PlaybackProgress, filename parsing
    FilmLibrary/   Local library persistence and queries
    FilmSources/   User-selected source adapters; transport abstraction
  Tests/           Domain, protocol, persistence and concurrency regression
Playback/          Playback protocol; AVFoundation and VideoLAN adapters
Tests/             Platform integration and XCUITest flows
scripts/           Generation, validation, packaging and release gates
docs/              Product, architecture, testing, privacy and release
.github/           CI and issue templates
```

## Data and security

Stable identity includes source identity and canonical file / server item path. Progress belongs to this identity, independent of display names. Local file security-scoped bookmarks retain access on macOS; iOS imports selected files into the sandbox. Deleting a library entry does not delete user files.

Library writes are atomic, serialized, schema versioned and bounded. Corrupt data is preserved for recovery rather than overwritten silently. Source credentials and tokens live in Keychain; only source IDs and endpoint configuration live in the library. Network requests have timeouts and cancellation. Cross-host redirects must not inherit credentials. WebDAV traversal stays within its configured origin / root; XML external entity resolution is disabled.

## Sources

`MediaSourceProvider` supplies paged listings and authenticated playback resources. Adapters share no UI state. Source selection is pending; the interface must accommodate local files, NAS protocols and media servers without treating WebDAV / Jellyfin as an approved first-release choice.

If selected, WebDAV uses `PROPFIND` for one directory at a time and HTTP range streaming. A Jellyfin adapter authenticates, lists libraries / items, retrieves server metadata and resolves playback resources. SMB requires its own protocol adapter and access / streaming tests; a WebDAV adapter cannot satisfy an SMB requirement. Playback reporting must never block local progress persistence.

## Playback

`PlaybackEngine` abstracts load, play, pause, seek, rate, tracks, subtitle selection, errors, and disposal. AVFoundation is a candidate for system-supported streams; official VLCKit is a candidate for MKV and additional codecs. Neither a production dependency nor a binary release has been integrated. Pinning, binary platform coverage, redistribution obligations and real playback must be verified before choosing a backend. PiP / AirPlay on one backend must not be promised for all backends automatically.

Compatibility is proven with media fixtures rather than inferred from extensions. Decoding work stays off the main actor; UI publication is on the main actor. Stop observers, network work and security-scoped access when a session ends.

## UI

Shared SwiftUI feature views with platform navigation shells. Use native navigation, menus, sheets, sliders, buttons, and accessibility semantics. Glass belongs to the control layer. Long lists are lazy and cancel obsolete image requests. Loading / empty / permission / error / offline states are part of every feature.

## Build and release

XcodeGen defines distinct native macOS and iOS targets with minimum deployment targets 26.0. Versions have one source of truth. Shared package tests, platform builds, protocol integration and UI flows gate changes. Signing and notarization use existing local identities or CI secrets; no secrets enter Git. Release scripts must refuse publication with missing required evidence. Website changes occur in the existing site repository after binaries and distribution links are verified.
