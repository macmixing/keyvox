
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "KeyVoxWhisper",
    defaultLocalization: "en",
    platforms: [
        .macOS("13.3"),
        .iOS("18.0"),
    ],
    products: [
        .library(
            name: "KeyVoxWhisper",
            targets: ["KeyVoxWhisper"]
        ),
    ],
    dependencies: [
        .package(path: "../KeyVoxVoiceActivity"),
    ],
    targets: [
        .target(
            name: "KeyVoxWhisper",
            dependencies: [
                .product(name: "KeyVoxSpeechRuntime", package: "KeyVoxVoiceActivity"),
            ],
            resources: [
                .process("Resources"),
            ]
        ),
        .testTarget(
            name: "KeyVoxWhisperTests",
            dependencies: [
                "KeyVoxWhisper",
                .product(name: "KeyVoxSpeechRuntime", package: "KeyVoxVoiceActivity"),
            ]
        ),
    ]
)
