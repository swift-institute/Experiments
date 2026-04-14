// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "escapable-slot-inlinable-sqe",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "escapable-slot-inlinable-sqe",
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
                .enableExperimentalFeature("LifetimeDependence"),
                .enableUpcomingFeature("InternalImportsByDefault"),
                .strictMemorySafety(),
            ]
        )
    ]
)
