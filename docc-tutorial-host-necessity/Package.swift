// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "docc-tutorial-host-necessity",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "Demo", targets: ["Demo"]),
    ],
    targets: [
        .target(name: "Demo")
    ]
)
