// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "property-view-valued-storage-arg",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(path: "../.."),
    ],
    targets: [
        .executableTarget(
            name: "property-view-valued-storage-arg",
            dependencies: [
                .product(name: "Property Primitives", package: "swift-property-primitives"),
                .product(name: "Property Inout Primitives", package: "swift-property-primitives"),
            ],
            swiftSettings: [
                .enableExperimentalFeature("ValueGenerics"),
                .enableExperimentalFeature("SuppressedAssociatedTypes"),
                .enableExperimentalFeature("LifetimeDependence"),
                .enableExperimentalFeature("Lifetimes"),
            ]
        )
    ]
)
