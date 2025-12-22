// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GemViz",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "GemVizCore",
            targets: ["GemVizCore"]
        ),
    ],
    targets: [
        .target(
            name: "GemVizCore",
            path: "GemVizCore"
        ),
    ]
)
