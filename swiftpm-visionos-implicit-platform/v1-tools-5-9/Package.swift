// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "v1-tools-5-9",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "v1-tools-5-9", targets: ["v1-tools-5-9"])
    ],
    targets: [
        .target(name: "v1-tools-5-9")
    ]
)
