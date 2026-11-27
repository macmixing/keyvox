// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KeyVoxTypingHarness",
    platforms: [.macOS("13.3")],
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
