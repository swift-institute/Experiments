// swift-tools-version: 6.3
import PackageDescription

// Design-convergence spike for the String/Path parameterization arc.
// Re-validates Option G's two-level @_lifetime chain through a GENERIC RawValue
// (String<Char, Backing>) — baseline open question §8.3. Mirrors the multi-package
// shape of `tagged-two-level-lifetime` (Tagged in a separate module from the
// String + the Tagged extensions) so cross-module @_lifetime propagation is tested
// exactly as the production cascade will hit it (Tagged in swift-tagged-primitives,
// String in swift-string-primitives).
let package = Package(
    name: "tagged-generic-rawvalue-lifetime",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(path: "TaggedLib"),
    ],
    targets: [
        .target(
            name: "StringLib",
            dependencies: [.product(name: "TaggedLib", package: "TaggedLib")],
            swiftSettings: [
                .strictMemorySafety(),
                .enableExperimentalFeature("Lifetimes"),
                .enableExperimentalFeature("LifetimeDependence"),
            ]
        ),
        .executableTarget(
            name: "Consumer",
            dependencies: ["StringLib"],
            swiftSettings: [
                .strictMemorySafety(),
                .enableExperimentalFeature("Lifetimes"),
                .enableExperimentalFeature("LifetimeDependence"),
            ]
        ),
    ]
)
