// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "property-view-consuming-iterator",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "property-view-consuming-iterator",
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
                .enableExperimentalFeature("LifetimeDependenceDiagnosticsForReturnedConsuming"),
                .enableExperimentalFeature("SuppressedAssociatedTypes"),
                .enableExperimentalFeature("BuiltinModule"),
                .strictMemorySafety(),
            ]
        )
    ]
)
