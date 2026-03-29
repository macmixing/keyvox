// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "KeyVoxParakeet",
    platforms: [
        .macOS(.v13),
        .iOS("18.0"),
    ],
    products: [
        .library(
            name: "KeyVoxParakeet",
            targets: ["KeyVoxParakeet"]
        ),
    ],
    targets: [
        .target(
            name: "KeyVoxParakeet",
            path: "Sources/KeyVoxParakeet"
        ),
        .testTarget(
            name: "KeyVoxParakeetTests",
            dependencies: ["KeyVoxParakeet"],
            path: "Tests/KeyVoxParakeetTests"
        ),
    ]
)
