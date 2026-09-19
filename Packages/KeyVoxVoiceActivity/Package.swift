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
            url: "https://github.com/ggml-org/whisper.cpp/releases/download/b5130/whisper-b5130-xcframework.zip",
            checksum: "033a43b0174e8cf9b366f72e4a428cdcf126f93ad1c87d3fa119a96bed6f231a"
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
