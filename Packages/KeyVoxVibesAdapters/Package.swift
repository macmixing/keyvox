// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "KeyVoxVibesAdapters",
    platforms: [
        .iOS(.v18),
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "KeyVoxVibesAdapters",
            targets: ["KeyVoxVibesAdapters"]
        ),
    ],
    targets: [
        .target(
            name: "KeyVoxVibesAdapters",
            resources: [
                .copy("Resources/Adapters"),
            ]
        ),
        .testTarget(
            name: "KeyVoxVibesAdaptersTests",
            dependencies: ["KeyVoxVibesAdapters"]
        ),
    ]
)
