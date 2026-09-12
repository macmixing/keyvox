// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KeyVoxModels",
    platforms: [.iOS(.v18), .macOS(.v13)],
    products: [.library(name: "KeyVoxModels", targets: ["KeyVoxModels"])],
    dependencies: [
        .package(url: "https://github.com/apple/swift-crypto.git", exact: "4.5.2")
    ],
    targets: [
        .target(name: "KeyVoxModels", dependencies: [
            .product(name: "Crypto", package: "swift-crypto")
        ]),
        .testTarget(name: "KeyVoxModelsTests", dependencies: ["KeyVoxModels"])
    ]
)
