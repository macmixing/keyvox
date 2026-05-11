// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "KeyVoxLocalInference",
    platforms: [
        .iOS("18.0"),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "KeyVoxLocalInference",
            targets: ["KeyVoxLocalInference"]
        )
    ],
    dependencies: [
        .package(path: "../KeyVoxStyleRewrite")
    ],
    targets: [
        .binaryTarget(
            name: "llama",
            path: "Artifacts/llama.xcframework"
        ),
        .target(
            name: "KeyVoxLocalInference",
            dependencies: ["llama"],
            path: "Sources/KeyVoxLocalInference"
        ),
        .testTarget(
            name: "KeyVoxLocalInferenceTests",
            dependencies: [
                "KeyVoxLocalInference",
                .product(name: "KeyVoxStyleRewrite", package: "KeyVoxStyleRewrite")
            ],
            path: "Tests/KeyVoxLocalInferenceTests"
        )
    ]
)
