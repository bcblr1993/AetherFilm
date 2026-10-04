// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "VLCKit",
    platforms: [.macOS("26.0"), .iOS("26.0")],
    products: [.library(name: "VLCKit", targets: ["VLCKit"])],
    targets: [.binaryTarget(
        name: "VLCKit",
        url: "https://github.com/bcblr1993/AetherFilm/releases/download/vlckit-8f5ce02-aether-20261004/VLCKit-AetherFilm-native6-arm64.xcframework.zip",
        checksum: "ced058ad2baa7cb74b4b1a842abbc0573a6f3bf6ddcd11f83c04d997c8414005"
    )]
)
