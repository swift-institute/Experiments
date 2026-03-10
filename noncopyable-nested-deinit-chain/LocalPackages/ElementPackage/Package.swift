// swift-tools-version: 6.2
import PackageDescription
let package = Package(
    name: "ElementPackage",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "Element", targets: ["Element"])
    ],
    targets: [
        .target(name: "Element")
    ]
)
