// swift-tools-version: 6.3.1
import PackageDescription

let package = Package(
    name: "property-view-ownership-inout-factoring",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(url: "https://github.com/swift-primitives/swift-ownership-primitives.git", branch: "main"),
        .package(url: "https://github.com/swift-primitives/swift-tagged-primitives.git", branch: "main"),
        .package(path: "../../../swift-property-primitives"),
    ],
    targets: [
        .executableTarget(
            name: "property-view-ownership-inout-factoring",
            dependencies: [
                .product(name: "Ownership Primitives", package: "swift-ownership-primitives"),
                .product(name: "Tagged Primitives", package: "swift-tagged-primitives"),
                .product(name: "Property Primitives", package: "swift-property-primitives"),
            ],
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
                .enableExperimentalFeature("SuppressedAssociatedTypes"),
            ]
        )
    ]
)
