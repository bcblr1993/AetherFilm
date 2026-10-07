# AetherVLCBridge

Static, namespaced Objective-C player wrapper for AetherFilm. Minimum macOS and iOS versions are **26.0**. Both the application and this bridge use the canonical `../AetherVLCKit` package. It contains the artifact checksum and corresponding source for the locally rebuilt three-platform ARM64 backend, derived from official wrapper revision `8f5ce02f09a7da5d061a24ddac3cb432f2a9b332`.

The owned `AetherVLCMediaPlayer` class uses the original wrapper implementation in a distinct namespace. It does not access the private player handle of a stock `VLCMediaPlayer` instance or swizzle that class. The native core includes the explicit changes recorded in `../AetherVLCKit/Patches`. The public header imports enum and media types through `<VLCKit/...>`. Necessary original internal declarations stay target-private; the 15 pinned public C headers live under `Vendor/vlc` for reproducible nested `<vlc/...>` imports.

The delegate adds four explicit Swift contracts:

```swift
mediaPlayerStopping(reason:inputTime:hadError:)
mediaPlayerClockPoint(time:position:systemDate:)
mediaPlayerInputPositionChanged(time:position:)
mediaPlayerSeekingChanged(_:targetTime:sequence:)
```

Stopping reasons have a compile-time assertion against the fixed public C ABI. Input time, error and seek callback snapshots are copied under an owned `NSLock` before asynchronous delegate delivery. The event handler owns a standalone primitive snapshot; native callbacks access it without promoting the weak player, so snapshot release cannot destroy the native engine on its callback thread. The lock guards primitive values only; no delegate or libVLC operation runs while it is held. Clock interpolation updates the cache only when the original C function reports success. The prototype `measuredCoreTime` getter is absent. The readonly `diagnosticCoreTimeMicroseconds` getter is diagnostic evidence; it never clears the application's pending seek status. Seek completion and callback sequence likewise do not establish new presented output.

These values provide playback events, not proof that an SMB transfer completed. Source completeness and application lifecycle decisions belong to the application and source services.

## License and corresponding source

The modified wrapper and vendored headers retain their original copyrights and LGPL notices. See `COPYING.LGPL-2.1` and the notices in each file. The application repository's MIT license does not relicense this derived wrapper. Generated files changed by AetherNative carry a `2026-10-07` change banner. Unchanged helper and C headers retain their original bytes.

`PinnedInputs` contains the exact original wrapper inputs and public C headers used here. `Provenance/inputs.json` records their 23 SHA-256 values, the historical official archive, frozen namespaced source/header hashes and exact patch hash. The pinned headers remain that original baseline. The current native wrapper's `libvlc_version.h` additionally defines ABI version macros; the other 14 public headers match. The 4.0.0 version macros describe the headers, not a released LibVLC version.

This package is one component of the corresponding source. Distribution also requires the original VLCKit / libVLC corresponding source, patches and build instructions recorded by the main repository, plus the complete application source and its reproducible project specification. The package's compile evidence does not certify those release assets, Mac GUI behavior, physical-device playback or audible output.

## Reproduce generated sources

The two generators are deterministic:

1. `Tools/generate_namespaced_wrapper.py` derives the namespaced player from the fixed `PinnedInputs/Wrapper` files.
2. `Tools/generate_package_sources.py` verifies every input and patch hash, applies the reviewed patch without fuzz, verifies the approved raw namespaced implementation/header hashes, and creates package-relative imports and dated banners.

Run from any directory, using a **new** output directory:

```sh
python3 /absolute/path/to/Packages/AetherVLCBridge/Tools/generate_package_sources.py \
  --require-frozen --output /absolute/path/to/new-generated-tree
```

The tool refuses to replace an existing `Sources/AetherVLCBridge` tree. It writes `generated-provenance.json` with all 22 generated source hashes. Two independent generations and the installed package reproduce those bytes; see `Provenance/reproduction-proof.json`.

## Build and test with a local binary mirror

The production `Package.swift` retains the canonical `../AetherVLCKit` dependency. A verified local mirror can support a build before publishing its immutable remote asset, without changing implementation bytes. Both the copied top-level project and copied bridge manifest must point to the **same canonical package path**. The formal artifact metadata records whether its remote asset has actually been published.

Use a mirror with this manifest and the extracted, checksum-verified fixed `VLCKit.xcframework`:

```swift
// swift-tools-version: 6.0
import PackageDescription
let package = Package(name: "VLCKit", platforms: [.macOS("26.0"), .iOS("26.0")],
    products: [.library(name: "VLCKit", targets: ["VLCKit"])],
    targets: [.binaryTarget(name: "VLCKit", path: "VLCKit.xcframework")])
```

Create an owned diagnostic application copy:

```sh
python3 Packages/AetherVLCBridge/Tools/prepare_local_mirror.py \
  --project-root /absolute/path/to/application-source \
  --bridge-snapshot /absolute/path/to/Packages/AetherVLCBridge \
  --vlckit-mirror /absolute/path/to/verified/LocalVLCKit \
  --output /absolute/path/to/new-diagnostic-project
```

The helper uses system Ruby's YAML parser. It copies tracked and non-ignored new repository files, or verifies a frozen source asset's manifest hashes, and records the exact project/package manifest diffs and unchanged bridge source hashes. Repository working-copy exports must not be described as immutable commit exports. The helper does not generate the Xcode project, change the original source, launch an App or operate a Simulator. Generate and build only the copied project when needed.

Run the current three-platform ARM64 callback consumer matrix:

```sh
python3 Packages/AetherVLCBridge/Tools/verify_package_consumers.py \
  --package-snapshot /absolute/path/to/Packages/AetherVLCBridge \
  --vlckit-mirror /absolute/path/to/verified/LocalVLCKit \
  --output /absolute/path/to/new-consumer-evidence
```

This requires an owner-approved frozen snapshot, verifies its generated inventory, and keeps the manifest override in its own copy. It compiles actual optional Swift protocol calls and Objective-C selectors, with `nonisolated` delegate methods passing primitives to `MainActor`. The three current ARM64 consumers compiled and linked successfully with the Native8 artifact at minimum26; see `Provenance/consumer-build-review.json`. The earlier five-platform evidence remains in `Provenance/History`. No `unsafeFlags` are required. These builds do not launch the consumer or any device, and do not certify App or distribution acceptance.
