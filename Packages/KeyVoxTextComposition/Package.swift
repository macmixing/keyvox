// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "KeyVoxTextComposition",
    platforms: [
        .iOS(.v18),
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "KeyVoxTextComposition",
            targets: ["KeyVoxTextComposition"]
        ),
    ],
    targets: [
        .target(name: "KeyVoxTextComposition"),
        .testTarget(
            name: "KeyVoxTextCompositionTests",
            dependencies: ["KeyVoxTextComposition"]
        ),
    ]
)
