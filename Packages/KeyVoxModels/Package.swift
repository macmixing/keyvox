// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KeyVoxModels",
    platforms: [.iOS(.v18), .macOS(.v13)],
    products: [.library(name: "KeyVoxModels", targets: ["KeyVoxModels"])],
    targets: [.target(name: "KeyVoxModels")]
)
