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
    dependencies: [.package(path: "../KeyVoxState")],
    targets: [
        .target(
            name: "KeyVoxPromotions",
            dependencies: [.product(name: "KeyVoxState", package: "KeyVoxState")],
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "KeyVoxPromotionsTests",
            dependencies: ["KeyVoxPromotions"]
        ),
    ]
)
