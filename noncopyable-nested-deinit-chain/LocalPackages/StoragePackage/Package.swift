// swift-tools-version: 6.2
import PackageDescription
let package = Package(
    name: "StoragePackage",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "Storage", targets: ["Storage"])
    ],
    targets: [
        .target(
            name: "Storage",
            swiftSettings: [
                .enableExperimentalFeature("RawLayout"),
            ]
        )
    ]
)
