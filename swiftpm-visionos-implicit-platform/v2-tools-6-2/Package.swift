// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "v2-tools-6-2",
    platforms: [.macOS(.v26), .iOS(.v26)],
    products: [
        .library(name: "v2-tools-6-2", targets: ["v2-tools-6-2"])
    ],
    targets: [
        .target(name: "v2-tools-6-2")
    ]
)
