// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KeyVoxLinguistics",
    platforms: [.macOS(.v13), .iOS(.v18)],
    products: [.library(name: "KeyVoxLinguistics", targets: ["KeyVoxLinguistics"])],
    targets: [
        .target(name: "KeyVoxLinguistics", resources: [.copy("Resources/PERCEPTRON-LICENSE.txt")]),
        .testTarget(name: "KeyVoxLinguisticsTests", dependencies: ["KeyVoxLinguistics"]),
    ]
)
