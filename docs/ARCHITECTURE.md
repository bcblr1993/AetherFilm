# Architecture

## Principles

Native SwiftUI apps, shared domain and services, explicit side effects, Swift 6 concurrency. Observable `AppStore` owns application state; views never access NAS credentials or implement SMB requests. Phase one is local files and SMB NAS. Read `PRODUCT.md` before adding sources or a metadata library.

```text
Apps/
  Shared/          App entry, AppStore, Keychain and SwiftUI feature views
  Resources/       Original icon and platform asset catalogs
  macOS/           Generated Info.plist and sandbox entitlements
  iOS/             Generated platform configuration
Packages/AetherFilmKit/
  Sources/
    FilmDomain/    MediaItem, SMBConnection, path/range rules and progress
    FilmLibrary/   Schema-versioned atomic library persistence
    FilmSources/   SMBProvider and loopback HTTP range streaming
  Tests/           Domain, storage, SMB transport and streaming regressions
Packages/AetherVLCBridge/
  Sources/         Namespaced LGPL player wrapper and pinned public C headers
  Provenance/      Exact inputs, generated-source and consumer-build records
Playback/          FilmPlayer and native VLC video surfaces
PlaybackTests/     Real generated media playback integration
Tests/             AppStore integration and cross-platform XCUITest flows
scripts/           Fixture generation, validation and release tooling
docs/              Product, architecture, evidence, privacy and release gates
.github/           Reproducible build and shared-package CI
```

## Data and access

Media identity combines the source identity and canonical path; imported local files retain an import identity even when iOS copies them into its sandbox. Progress uses this identity and does not depend on display names. macOS retains user-granted security-scoped bookmarks. iOS copies chosen videos into Documents/Imports. Removing a library entry never deletes the original video.

`LibraryStore` is an actor. It serializes atomic writes, checks the schema and preserves corrupt or future-schema data instead of replacing it silently. `LibrarySnapshot` holds connections, local items, bounded recent history and playback progress. NAS passwords are stored only in Keychain; connection records contain endpoint configuration and source IDs.

## SMB and streaming

`SMBFileProviding` accepts a connection and ephemeral credentials for listing, file size and bounded range reads. `SMBProvider` wraps pinned AMSMB2 4.0.3. Its sessions validate configuration and credentials, cap reads and timeouts, map protocol errors to safe messages and avoid reusing cancelled sessions. Canonical paths reject traversal and stay inside the chosen root. An optional required-encryption setting fails closed when the negotiated server cannot provide encryption.

For playback, `AppStore` starts `SMBStreamingServer` on **127.0.0.1** with a random unguessable route. VLC receives this credential-free URL. The bridge supports GET, HEAD and one HTTP byte range, including suffix ranges, and streams bounded chunks instead of downloading the whole film. It limits active clients, cancels abandoned seek requests and stops listeners and reads when playback closes. No LAN HTTP listener or persistent local HTTP password is created.

The stream actor retains the first sanitized source `readFailure()`. A provider read error, premature empty data or an oversized reply publishes this state before notifying `onReadFailure` and before closing the incomplete HTTP response. A nonempty short read continues from its actual byte count. Consumer send errors or RST, cancellation, stop and obsolete request/server generations do not become NAS read failures. A valid client write half-close still receives the full response. Failure remains queryable after stop; explicit Retry creates a new server instance and a new playback generation.

`AppStore` receives the observer on the main actor, validates the current generation and item, exposes the existing error/retry UI and stops the failed stream. Completion uses the actor query rather than waiting for that UI notification. `PreparedPlayback` returns the URL and its generation together. `canCompletePlayback` captures the current stream, awaits its failure state and rechecks generation, source item and presented item. Automatic next-video selection checks again after saving progress. Manual next checks its captured generation after saving without marking unfinished content watched. View cleanup carries the captured session; resources are cleared and the old stream is captured before awaiting its stop, so an old teardown cannot stop a same-item retry.

## Playback

`FilmPlayer` uses the official fixed VLCKit 4.0.0-a25 package. It owns a fresh VLC session and delegate per film. Session tokens ignore stale callbacks. It publishes playback position, duration, actual tracks, chapters, rate, seekability and errors on the main actor. Decode and protocol work remain in their underlying engines. macOS uses `VLCVideoView`; iOS uses a native UIView drawable and AVAudioSession movie playback with interruption and route handling.

On iOS, `AudioSessionCoordinator` performs synchronous audio configuration and activation on a dedicated serial background queue, including on the minimum supported iOS 26. Successful activations hold owner leases; an inactive or disposed player cannot deactivate another player's session. The main actor validates the current film, activation request, play intent and native drawable before starting VLC after the worker completes. Loading combines backend buffering with audio preparation, so pause can cancel the current intent while preparation is still pending.

Delegate notifications may be queued after the underlying playback state has already changed. A late paused notification checks the engine's current state before publishing the play/pause control state. A regression holds and releases an actual VLC paused callback after real playback resumes, then verifies that toggle pauses the real output and clock.

The player waits for its native drawable before starting, retains security-scoped subtitle access, reports opening timeouts and releases decoder, audio session and file access when stopped. `AppStore` periodically persists progress and flushes it on pause or dismissal. The 95% watched threshold and final EOS-driven automatic next-video selection are separate decisions. A confirmed progress checkpoint may mark an item watched at 95%; an unconfirmed seek target passes `allowsAutomaticWatched: false`, preserving its position for resume. Reaching that threshold alone never selects the next video.

The source-controlled `AetherVLCBridge` derives a namespaced player from the pinned official wrapper and adds typed stopping, clock and input-position callbacks. It leaves the fixed libVLC core unchanged and retains LGPL notices. The candidate completion adapter combines typed EOS with current-session validation, confirmed input/output evidence and the SMB source-health gate. Typed EOS or a time value equal to duration alone cannot prove a complete source: a real near-tail transport fault reproduced both. Isolated playback and five-platform bridge consumer checks are recorded in `BACKEND_EVIDENCE.md`; they do not certify the final combined app, CI or device/distribution acceptance.

The backend is a pre-release dependency. Its exact binary checksum, source/build evidence and redistribution notices live in `BACKEND_EVIDENCE.md` and `THIRD_PARTY_NOTICES.md`. Container names are browsing filters, not a promise that every codec combination works. Compatibility claims require real output checks and a completed test matrix.

## UI

macOS and iPad use system split navigation; iPhone uses a navigation stack and fullscreen playback. Native Liquid Glass belongs to navigation and floating controls; content stays readable. Empty, importing, loading, error/retry and missing-source states are part of each flow. System Dynamic Type, VoiceOver labels and Reduce Transparency must be tested. DEBUG UI fixtures use an isolated temporary library and never access a user's NAS or Keychain.

## Build and release

`project.yml` generates both app and test targets with XcodeGen. `Version.xcconfig` is the single version/build and minimum-OS source. Generated projects and downloaded binaries are ignored. Dependencies are fixed by exact version or commit. CI verifies shared tests and platform builds; Tart `macos27` verifies desktop UI and real iPhone evidence remains separate. Release signing uses existing identities without exporting keys. `RELEASE.md` defines the distribution gates and website verification order.

The macOS app uses a single native Window scene because playback and its SMB stream have one owner. Opening another app window must not duplicate audio or let one window dispose another player’s stream. iOS uses the native WindowGroup scene.
