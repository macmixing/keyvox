// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "KeyVoxTTS",
    platforms: [
        .macOS(.v13),
        .iOS("18.0"),
    ],
    products: [
        .library(
            name: "KeyVoxTTS",
            targets: ["KeyVoxTTS"]
        ),
    ],
    targets: [
        .target(
            name: "KeyVoxTTS",
            path: "Sources/KeyVoxTTS"
        ),
        .testTarget(
            name: "KeyVoxTTSTests",
            dependencies: ["KeyVoxTTS"],
            path: "Tests/KeyVoxTTSTests"
        ),
    ]
)
