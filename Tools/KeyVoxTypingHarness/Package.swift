// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KeyVoxTypingHarness",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(path: "../../Packages/KeyVoxPredictiveKeyboard"),
    ],
    targets: [
        .executableTarget(
            name: "KeyVoxTypingHarness",
            dependencies: [
                .product(name: "KeyVoxPredictiveKeyboard", package: "KeyVoxPredictiveKeyboard"),
            ]
        ),
    ]
)
