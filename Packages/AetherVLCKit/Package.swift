// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "VLCKit",
    platforms: [.macOS("26.0"), .iOS("26.0")],
    products: [.library(name: "VLCKit", targets: ["VLCKit"])],
    targets: [.binaryTarget(
        name: "VLCKit",
        url: "https://github.com/bcblr1993/AetherFilm/releases/download/vlckit-8f5ce02-aether-20261004/VLCKit-AetherFilm-native7-arm64.xcframework.zip",
        checksum: "f629ad7fd1f02aa3fef00a1808bf85e8ccb7b6916c5263d0b0238faaad261e35"
    )]
)
