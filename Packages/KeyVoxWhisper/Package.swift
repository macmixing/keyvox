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
            url: "https://github.com/ggml-org/whisper.cpp/releases/download/v1.7.5/whisper-v1.7.5-xcframework.zip",
            checksum: "c7faeb328620d6012e130f3d705c51a6ea6c995605f2df50f6e1ad68c59c6c4a"
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
