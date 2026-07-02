// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "Kit",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "WallKit", targets: ["WallKit"])
    ],
    targets: [
        .target(
            name: "WallKit",
            swiftSettings: [
                .enableExperimentalFeature("SuppressedAssociatedTypes"),
                .enableExperimentalFeature("RawLayout"),
            ]
        )
    ]
)
