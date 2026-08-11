// swift-tools-version: 6.3.1
import PackageDescription

let package = Package(
    name: "property-view-lifetime-escape-reproduction",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(url: "https://github.com/swift-primitives/swift-ownership-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-tagged-primitives.git", branch: "main"),
        .package(path: "../../../swift-property-primitives"),
        .package(url: "https://github.com/swift-primitives/swift-buffer-primitives.git", branch: "main"),
    ],
    targets: [
        .executableTarget(
            name: "property-view-lifetime-escape-reproduction",
            dependencies: [
                .product(name: "Ownership Primitives", package: "swift-ownership-primitives"),
                .product(name: "Tagged Primitives", package: "swift-tagged-primitives"),
                .product(name: "Property Primitives", package: "swift-property-primitives"),
                .product(name: "Property View Primitives", package: "swift-property-primitives"),
                .product(name: "Property View Read Primitives", package: "swift-property-primitives"),
                .product(name: "Buffer Primitives", package: "swift-buffer-primitives"),
                .product(name: "Buffer Ring Primitives", package: "swift-buffer-primitives"),
            ],
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
                .enableExperimentalFeature("SuppressedAssociatedTypes"),
            ]
        )
    ]
)
