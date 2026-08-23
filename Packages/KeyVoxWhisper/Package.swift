
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "KeyVoxWhisper",
    platforms: [
        .macOS(.v13),
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
