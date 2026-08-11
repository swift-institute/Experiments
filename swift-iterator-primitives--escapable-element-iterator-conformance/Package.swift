// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "escapable-element-iterator-conformance",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(path: "../..")
    ],
    targets: [
        .executableTarget(
            name: "escapable-element-iterator-conformance",
            dependencies: [
                .product(name: "Iterator Primitives", package: "swift-iterator-primitives")
            ],
            swiftSettings: [
                .enableExperimentalFeature("LifetimeDependence"),
                .enableExperimentalFeature("Lifetimes"),
                .enableExperimentalFeature("SuppressedAssociatedTypes"),
            ]
        )
    ]
)
