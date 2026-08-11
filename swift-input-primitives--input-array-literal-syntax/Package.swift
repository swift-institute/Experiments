// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "input-array-literal-syntax",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(path: "../../"),
    ],
    targets: [
        .executableTarget(
            name: "input-array-literal-syntax",
            dependencies: [
                .product(name: "Input Primitives", package: "swift-input-primitives"),
            ],
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
                .enableUpcomingFeature("MemberImportVisibility"),
                .enableExperimentalFeature("Lifetimes"),
                .enableExperimentalFeature("SuppressedAssociatedTypes"),
                .enableExperimentalFeature("NonescapableTypes"),
                .enableExperimentalFeature("LifetimeDependence"),
                .strictMemorySafety(),
            ]
        )
    ]
)
