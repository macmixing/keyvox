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
    dependencies: [
        .package(path: "../KeyVoxLinguistics"),
    ],
    targets: [
        .target(
            name: "KeyVoxTTS",
            dependencies: [
                .product(name: "KeyVoxLinguistics", package: "KeyVoxLinguistics"),
            ],
            path: "Sources/KeyVoxTTS"
        ),
        .testTarget(
            name: "KeyVoxTTSTests",
            dependencies: [
                "KeyVoxTTS",
                .product(name: "KeyVoxLinguistics", package: "KeyVoxLinguistics"),
            ],
            path: "Tests/KeyVoxTTSTests"
        ),
    ]
)
