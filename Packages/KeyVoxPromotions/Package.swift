// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "KeyVoxPromotions",
    platforms: [
        .iOS(.v18),
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "KeyVoxPromotions",
            targets: ["KeyVoxPromotions"]
        ),
    ],
    targets: [
        .target(
            name: "KeyVoxPromotions",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "KeyVoxPromotionsTests",
            dependencies: ["KeyVoxPromotions"]
        ),
    ]
)
