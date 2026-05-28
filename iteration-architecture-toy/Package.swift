// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "iteration-architecture-toy",
    platforms: [.macOS(.v26)],
    targets: [
        // Gap (c): a SECOND target in the same package. Houses the family protocol + the ~Escapable
        // view type(s) + conformers for D1 / route-3 forEach (C) / route-2, so the executable can
        // exercise them ACROSS A MODULE BOUNDARY ([EXP-017]).
        .target(name: "iteration-architecture-toy-lib"),
        .executableTarget(
            name: "iteration-architecture-toy",
            dependencies: ["iteration-architecture-toy-lib"]
        ),
    ]
)

// Ecosystem-standard Swift settings (faithful to the real institute packages).
for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    let ecosystem: [SwiftSetting] = [
        .strictMemorySafety(),
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
        .enableExperimentalFeature("LifetimeDependence"),
        .enableExperimentalFeature("Lifetimes"),
        .enableExperimentalFeature("SuppressedAssociatedTypes"),
        .enableUpcomingFeature("InferIsolatedConformances"),
        .enableUpcomingFeature("LifetimeDependence"),
    ]

    let package: [SwiftSetting] = []

    target.swiftSettings = (target.swiftSettings ?? []) + ecosystem + package
}
