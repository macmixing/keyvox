// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "KeyVoxEmoji",
    platforms: [
        .iOS("18.0"),
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "KeyVoxEmoji",
            targets: ["KeyVoxEmoji"]
        ),
    ],
    targets: [
        .target(
            name: "KeyVoxEmoji",
            path: "Sources/KeyVoxEmoji",
            resources: [.copy("EmojiData")]
        ),
        .testTarget(
            name: "KeyVoxEmojiTests",
            dependencies: ["KeyVoxEmoji"],
            path: "Tests/KeyVoxEmojiTests"
        ),
    ]
)
