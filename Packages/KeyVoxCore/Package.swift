// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "KeyVoxCore",
    platforms: [
        .macOS(.v13),
        .iOS("18.0"),
    ],
    products: [
        .library(
            name: "KeyVoxCore",
            targets: ["KeyVoxCore"]
        ),
    ],
    dependencies: [
        .package(path: "../KeyVoxWhisper"),
        .package(path: "../KeyVoxParakeet"),
    ],
    targets: [
        .target(
            name: "KeyVoxCore",
            dependencies: [
                .product(name: "KeyVoxWhisper", package: "KeyVoxWhisper"),
                .product(name: "KeyVoxParakeet", package: "KeyVoxParakeet"),
            ],
            resources: [
                .process("Resources"),
            ]
        ),
        .testTarget(
            name: "KeyVoxCoreTests",
            dependencies: ["KeyVoxCore"]
        ),
    ]
)
