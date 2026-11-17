// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "KeyVoxParakeet",
    defaultLocalization: "en",
    platforms: [
        // Keep the package deployment target at Ventura so macOS 13 app targets in the workspace
        // can still resolve and archive. Parakeet itself is runtime-gated and is only expected to
        // be available on macOS 14 and later.
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
            path: "Sources/KeyVoxParakeet",
            resources: [
                .process("Resources"),
            ]
        ),
        .testTarget(
            name: "KeyVoxParakeetTests",
            dependencies: ["KeyVoxParakeet"],
            path: "Tests/KeyVoxParakeetTests"
        ),
    ]
)
