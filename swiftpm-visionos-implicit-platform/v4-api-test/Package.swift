// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "v4-api-test",
    platforms: [.macOS(.v26), .iOS(.v26), .visionOS(.v26)],
    products: [
        .library(name: "v4-api-test", targets: ["v4-api-test"])
    ],
    targets: [
        .target(name: "v4-api-test")
    ]
)
