// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "borrow-pointer-storage-release-miscompile",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "borrow-pointer-storage-release-miscompile",
            path: "Sources",
            swiftSettings: [
                .enableExperimentalFeature("LifetimeDependence"),
                .enableExperimentalFeature("Lifetimes"),
                .enableExperimentalFeature("SuppressedAssociatedTypes"),
                .enableExperimentalFeature("AddressableTypes"),
            ]
        )
    ]
)
