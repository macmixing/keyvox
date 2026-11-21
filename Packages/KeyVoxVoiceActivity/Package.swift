// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "KeyVoxVoiceActivity",
    platforms: [
        .macOS("13.3"),
        .iOS("18.0"),
    ],
    products: [
        .library(
            name: "KeyVoxVoiceActivity",
            targets: ["KeyVoxVoiceActivity"]
        ),
        .library(
            name: "KeyVoxSpeechRuntime",
            targets: ["KeyVoxSpeechRuntime"]
        ),
    ],
    targets: [
        .binaryTarget(
            name: "whisper",
            path: "Artifacts/whisper.xcframework"
        ),
        .target(
            name: "KeyVoxSpeechRuntime",
            dependencies: [
                .target(name: "whisper", condition: .when(platforms: [.macOS, .iOS])),
                "CWhisper",
            ]
        ),
        .target(name: "CWhisper", publicHeadersPath: "include"),
        .target(
            name: "KeyVoxVoiceActivity",
            dependencies: ["KeyVoxSpeechRuntime"],
            resources: [
                .process("Resources"),
            ]
        ),
        .testTarget(
            name: "KeyVoxVoiceActivityTests",
            dependencies: ["KeyVoxVoiceActivity"]
        ),
    ]
)
