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
            path: "Artifacts/whisper.xcframework"
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
