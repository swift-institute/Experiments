// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "borrow-pointer-storage-release-miscompile",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "borrow-pointer-storage-release-miscompile",
            dependencies: ["V10FieldOfSelfLib"],
            path: "Sources",
            exclude: ["V10FieldOfSelfLib"],
            swiftSettings: [
                .enableExperimentalFeature("LifetimeDependence"),
                .enableExperimentalFeature("Lifetimes"),
                .enableExperimentalFeature("SuppressedAssociatedTypes"),
                .enableExperimentalFeature("AddressableTypes"),
            ]
        ),
        .target(
            name: "V10FieldOfSelfLib",
            path: "Sources/V10FieldOfSelfLib",
            swiftSettings: [
                .enableExperimentalFeature("LifetimeDependence"),
                .enableExperimentalFeature("Lifetimes"),
                .enableExperimentalFeature("SuppressedAssociatedTypes"),
                .enableExperimentalFeature("AddressableTypes"),
            ]
        ),
    ]
)
