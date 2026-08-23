// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "KeyVoxVoiceActivity",
    platforms: [
        .macOS(.v13),
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
            url: "https://github.com/ggml-org/whisper.cpp/releases/download/v1.7.6/whisper-v1.7.6-xcframework.zip",
            checksum: "9fcb28106d0b94a525e59bec057e35b57033195ac7408d7e1ab8e4b597cdfeb5"
        ),
        .target(
            name: "KeyVoxSpeechRuntime",
            dependencies: ["whisper"]
        ),
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
