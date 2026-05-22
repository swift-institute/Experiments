// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "witness-multi-target-namespace-collision",
    platforms: [.macOS(.v26)],
    targets: [
        // Witness Namespace — declares the generic struct (analogue of swift-serializer-primitives'
        // "Serializer Namespace" target). No external deps per [MOD-017].
        .target(
            name: "Witness Namespace",
            dependencies: [],
            swiftSettings: settings
        ),

        // Witness Core — declares the hoisted protocol + typealias hoist + default extensions.
        // Depends on Namespace. Analogue of "Serializer Primitives Core".
        .target(
            name: "Witness Core",
            dependencies: ["Witness Namespace"],
            swiftSettings: settings
        ),

        // Consumer — declares a conformer to Witness.Protocol. Triggers the witness-table
        // emission that exposes the link failure (if any). Analogue of swift-version-primitives.
        .executableTarget(
            name: "Consumer",
            dependencies: ["Witness Core"],
            swiftSettings: settings
        ),
    ]
)

var settings: [SwiftSetting] {
    [
        .enableUpcomingFeature("ExistentialAny"),
        .enableExperimentalFeature("SuppressedAssociatedTypes"),
        .enableExperimentalFeature("Lifetimes"),
        .enableExperimentalFeature("LifetimeDependence"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
    ]
}
