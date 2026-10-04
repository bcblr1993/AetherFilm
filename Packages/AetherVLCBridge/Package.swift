// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "AetherVLCBridge",
    platforms: [.macOS("26.0"), .iOS("26.0")],
    products: [.library(name: "AetherVLCBridge", type: .static, targets: ["AetherVLCBridge"])],
    dependencies: [.package(name: "VLCKit", path: "../AetherVLCKit")],
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
