// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "KeyVoxStyleRewrite",
    platforms: [
        .iOS("18.0"),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "KeyVoxStyleRewrite",
            targets: ["KeyVoxStyleRewrite"]
        )
    ],
    targets: [
        .target(
            name: "KeyVoxStyleRewrite",
            path: "Sources/KeyVoxStyleRewrite"
        ),
        .testTarget(
            name: "KeyVoxStyleRewriteTests",
            dependencies: ["KeyVoxStyleRewrite"],
            path: "Tests/KeyVoxStyleRewriteTests"
        )
    ]
)
