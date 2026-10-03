# AetherVLCBridge

Static, namespaced Objective-C player wrapper for AetherFilm. Minimum macOS and iOS versions are **26.0**. The package depends on the official VLCKit binary product at revision `8f5ce02f09a7da5d061a24ddac3cb432f2a9b332`; its archive checksum is `f37c8dbdd4427d1a3f5d75dc4b8bd1ae863cef4426f9a405a2fd1c5c9012f1fb`.

The owned `AetherVLCMediaPlayer` class uses the original wrapper implementation in a distinct namespace. It does not access the private player handle of a stock `VLCMediaPlayer` instance or swizzle that class. The fixed libVLC core is unchanged. The public header imports stock enum and media types through `<VLCKit/...>`. Necessary original internal declarations stay target-private; the 15 public C headers delivered with the fixed binary live under `Vendor/vlc` for reproducible nested `<vlc/...>` imports.

The delegate adds three explicit Swift contracts:

```swift
mediaPlayerStopping(reason:inputTime:hadError:)
mediaPlayerClockPoint(time:position:systemDate:)
mediaPlayerInputPositionChanged(time:position:)
```

Stopping reasons have a compile-time assertion against the fixed public C ABI. Input time and error values are copied under an owned `NSLock` in the original C stopping callback, before the delegate event is queued. The lock guards primitive values only; no delegate or libVLC operation runs while it is held. Clock interpolation updates the cache only when the original C function reports success. The prototype `measuredCoreTime` diagnostic getter is absent from the public API.

These values provide playback events, not proof that an SMB transfer completed. Source completeness and application lifecycle decisions belong to the application and source services.

## License and corresponding source

The modified wrapper and vendored headers retain their original copyrights and LGPL notices. See `COPYING.LGPL-2.1` and the notices in each file. The application repository's MIT license does not relicense this derived wrapper. Generated files changed by AetherNative carry a `2026-10-03` change banner. Unchanged helper and C headers retain their original bytes.

`PinnedInputs` contains the exact original wrapper inputs and public C headers used here. `Provenance/inputs.json` records their 23 SHA-256 values, the official revision, fixed archive checksum, approved namespaced source/header hashes and exact patch hash. The C headers are byte-identical in the macOS, iOS and iOS Simulator slices; their 4.0.0 version macros describe the headers, not a released LibVLC version.

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

The production `Package.swift` must retain the official remote revision. A verified local mirror can accelerate an explicitly identified diagnostic build without changing implementation bytes. Both the copied top-level project and the copied bridge manifest must point to the **same canonical package path**; changing only the project's direct dependency leaves a separate remote dependency in the bridge.

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

The helper uses system Ruby's YAML parser. It copies tracked repository bytes, or verifies a frozen source asset's manifest hashes, and records the exact project/package manifest diffs and unchanged bridge source hashes. Repository working-copy exports must not be described as immutable commit exports. The helper does not generate the Xcode project, change the original source, launch an App or operate a Simulator. Generate and build only the copied project when needed.

Run the independent five-platform callback consumer matrix:

```sh
python3 Packages/AetherVLCBridge/Tools/verify_package_consumers.py \
  --package-snapshot /absolute/path/to/Packages/AetherVLCBridge \
  --vlckit-mirror /absolute/path/to/verified/LocalVLCKit \
  --output /absolute/path/to/new-consumer-evidence
```

This requires an owner-approved frozen snapshot, verifies its generated inventory, and keeps the manifest override in its own diagnostic copy. It compiles actual optional Swift protocol calls and Objective-C selectors, with `nonisolated` delegate methods passing primitives to `MainActor`. macOS arm64 / x86_64, iOS arm64, and Simulator arm64 / x86_64 have passed compile and strong-link verification at minimum version 26.0, using one binary artifact and compiler-enabled ARC. No `unsafeFlags` are required. These builds do not launch the consumer or any device. Actual hashes, UUIDs and limitations are in `Provenance/consumer-build-review.json`.
