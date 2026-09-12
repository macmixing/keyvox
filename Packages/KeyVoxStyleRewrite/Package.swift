// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "KeyVoxStyleRewrite",
    platforms: [
        .iOS("18.0"),
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "KeyVoxStyleRewrite",
            targets: ["KeyVoxStyleRewrite"]
        )
    ],
    dependencies: [
        .package(path: "../KeyVoxLinguistics"),
    ],
    targets: [
        .target(
            name: "KeyVoxStyleRewrite",
            dependencies: [
                .product(name: "KeyVoxLinguistics", package: "KeyVoxLinguistics"),
            ],
            path: "Sources/KeyVoxStyleRewrite"
        ),
        .testTarget(
            name: "KeyVoxStyleRewriteTests",
            dependencies: [
                "KeyVoxStyleRewrite",
                .product(name: "KeyVoxLinguistics", package: "KeyVoxLinguistics"),
            ],
            path: "Tests/KeyVoxStyleRewriteTests"
        )
    ]
)
