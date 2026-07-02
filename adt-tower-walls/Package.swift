// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "adt-tower-walls",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(path: "Kit")
    ],
    targets: [
        // Consumer target — exercises WallKit ACROSS A PACKAGE BOUNDARY ([EXP-017];
        // Wall 2 / swiftlang/swift#86652 keys on the cross-module value-witness classification).
        .executableTarget(
            name: "adt-tower-walls",
            dependencies: [.product(name: "WallKit", package: "Kit")],
            swiftSettings: [.enableExperimentalFeature("SuppressedAssociatedTypes")]
        )
    ]
)
