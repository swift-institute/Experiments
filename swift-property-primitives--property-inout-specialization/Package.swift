// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "property-inout-specialization",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(path: "../..")  // swift-property-primitives
    ],
    targets: [
        // Module A — "buffer-linear": storage protocol, concrete storage, generic core,
        // and the Property.Inout accessor surface (the real property-primitives pattern).
        .target(
            name: "PropCore",
            dependencies: [
                .product(name: "Property Primitives", package: "swift-property-primitives")
            ],
            swiftSettings: [
                .enableExperimentalFeature("SuppressedAssociatedTypes"),
                .enableExperimentalFeature("LifetimeDependence"),
                .enableExperimentalFeature("Lifetimes"),
            ]
        ),
        // Module B — separate consumer module ([EXP-017] cross-module).
        .executableTarget(
            name: "consumer",
            dependencies: ["PropCore"],
            swiftSettings: [
                .enableExperimentalFeature("LifetimeDependence"),
                .enableExperimentalFeature("Lifetimes"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
