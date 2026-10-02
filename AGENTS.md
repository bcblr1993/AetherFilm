# AetherFilm project guidance

- Use Chinese for user communication. Keep public API symbols and code in English.
- Minimum macOS / iOS deployment targets are 26.0; do not raise them for visual styling.
- Read `docs/PRODUCT.md` before expanding scope. First release stays small.
- Keep domain, library and source services in the shared Swift package; SwiftUI views call observable app state.
- Use system native Liquid Glass controls. Keep content readable and support Reduce Transparency, Dynamic Type and VoiceOver.
- Preserve user files. Library removal never deletes the original video. Secrets stay in Keychain and never in Git, logs, fixture recordings or screenshots.
- Pin third party dependencies and record licenses / corresponding source before distributing binaries.
- Test actual playback, protocol errors, persistence, both platform builds and the full UI state matrix. Prefer Tart `macos27` for desktop UI work; do not manipulate host keyboard / mouse.
- Generated projects must be reproducible from the checked-in specification. Version data must have one source of truth.
- Do not call a release complete with missing real-device or distribution evidence. Follow `docs/RELEASE.md` and update `docs/TEST_MATRIX.md` truthfully.
