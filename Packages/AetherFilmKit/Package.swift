// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "AetherFilmKit",
    platforms: [.macOS("26.0"), .iOS("26.0")],
    products: [
        .library(name: "FilmDomain", targets: ["FilmDomain"]),
        .library(name: "FilmLibrary", targets: ["FilmLibrary"]),
        .library(name: "FilmSources", targets: ["FilmSources"])
    ],
    dependencies: [.package(url: "https://github.com/amosavian/AMSMB2.git", exact: "4.0.3")],
    targets: [
        .target(name: "FilmDomain"),
        .target(name: "FilmLibrary", dependencies: ["FilmDomain"]),
        .target(name: "FilmSources", dependencies: ["FilmDomain", .product(name: "AMSMB2", package: "AMSMB2")]),
        .testTarget(name: "FilmDomainTests", dependencies: ["FilmDomain"]),
        .testTarget(name: "FilmLibraryTests", dependencies: ["FilmDomain", "FilmLibrary"]),
        .testTarget(name: "FilmSourcesTests", dependencies: ["FilmDomain", "FilmSources"])
    ]
)
