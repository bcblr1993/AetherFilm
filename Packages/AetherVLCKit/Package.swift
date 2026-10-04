// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "VLCKit",
    platforms: [.macOS("26.0"), .iOS("26.0")],
    products: [.library(name: "VLCKit", targets: ["VLCKit"])],
    targets: [.binaryTarget(
        name: "VLCKit",
        url: "https://github.com/bcblr1993/AetherFilm/releases/download/vlckit-8f5ce02-aether-20261004-native8/VLCKit-AetherFilm-native8-arm64.xcframework.zip",
        checksum: "1ae7007adbfe8881472682a928caa8cee5011114b4b6d3002a1337c223230260"
    )]
)
