// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "VLCKit",
    platforms: [.macOS("26.0"), .iOS("26.0")],
    products: [.library(name: "VLCKit", targets: ["VLCKit"])],
    targets: [.binaryTarget(
        name: "VLCKit",
        url: "https://github.com/bcblr1993/AetherFilm/releases/download/vlckit-8f5ce02-aether-20261008-native9/VLCKit-AetherFilm-native9-arm64.xcframework.zip",
        checksum: "d6afca5cc284709851bb82fc61e4148bfe4b4dffdfa7b53c3cebe52253520493"
    )]
)
