// swift-tools-version: 6.2
import PackageDescription
let package = Package(
    name: "escapable-pointer-primitives-test",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "escapable-pointer-primitives-test",
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
                .enableExperimentalFeature("LifetimeDependence"),
                .enableExperimentalFeature("AddressableTypes"),
                .enableExperimentalFeature("BuiltinModule"),
                .strictMemorySafety(),
            ]
        )
    ]
)
