// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "AetherVLCBridge",
    platforms: [.macOS("26.0"), .iOS("26.0")],
    products: [.library(name: "AetherVLCBridge", type: .static, targets: ["AetherVLCBridge"])],
    dependencies: [.package(url: "https://github.com/videolan/vlckit.git", revision: "8f5ce02f09a7da5d061a24ddac3cb432f2a9b332")],
    targets: [
        .target(
            name: "AetherVLCBridge",
            dependencies: [.product(name: "VLCKit", package: "VLCKit")],
            path: "Sources/AetherVLCBridge",
            publicHeadersPath: "include",
            cSettings: [.headerSearchPath("Private"), .headerSearchPath("Vendor")],
            linkerSettings: [
                .linkedFramework("Foundation"),
                .linkedFramework("AppKit", .when(platforms: [.macOS])),
                .linkedFramework("CoreServices", .when(platforms: [.macOS])),
                .linkedFramework("IOKit", .when(platforms: [.macOS])),
                .linkedFramework("UIKit", .when(platforms: [.iOS]))
            ])
    ])
