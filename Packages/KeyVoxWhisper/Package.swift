
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
    targets: [
        .binaryTarget(
            name: "whisper",
            url: "https://github.com/ggml-org/whisper.cpp/releases/download/v1.7.6/whisper-v1.7.6-xcframework.zip",
            checksum: "9fcb28106d0b94a525e59bec057e35b57033195ac7408d7e1ab8e4b597cdfeb5"
        ),
        .target(
            name: "KeyVoxWhisper",
            dependencies: ["whisper"],
            path: "Sources/KeyVoxWhisper"
        ),
        .testTarget(
            name: "KeyVoxWhisperTests",
            dependencies: ["KeyVoxWhisper"],
            path: "Tests/KeyVoxWhisperTests"
        ),
    ]
)
