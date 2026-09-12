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
        .target(name: "CompositionVerification", dependencies: ["KeyVoxTextComposition"], path: "Verification"),
        .executableTarget(name: "CompositionProbe", dependencies: ["CompositionVerification"], path: "Probe"),
        .testTarget(
            name: "KeyVoxTextCompositionTests",
            dependencies: ["KeyVoxTextComposition", "CompositionVerification"]
        ),
    ]
)
