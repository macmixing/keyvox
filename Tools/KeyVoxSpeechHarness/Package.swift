// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KeyVoxSpeechHarness",
    platforms: [.macOS(.v13)],
    dependencies: [
        .package(path: "../../Packages/KeyVoxWhisper"),
        .package(path: "../../Packages/KeyVoxVoiceActivity"),
    ],
    targets: [
        .executableTarget(
            name: "KeyVoxSpeechHarness",
            dependencies: [
                .product(name: "KeyVoxWhisper", package: "KeyVoxWhisper"),
                .product(name: "KeyVoxVoiceActivity", package: "KeyVoxVoiceActivity"),
            ]
        ),
    ]
)
