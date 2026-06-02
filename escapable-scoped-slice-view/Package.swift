// swift-tools-version: 6.3
import PackageDescription

// Experiment: escapable-scoped-slice-view
// See Sources/escapable-scoped-slice-view/main.swift for the consolidated
// hypothesis + result header.
//
// Four targets, built individually (mirrors collection-index-escapable-lifetime):
//   ScopedSliceKit           — the candidate viable shape (lib; cross-module per [EXP-017])
//   escapable-scoped-slice-view — cross-module consumer: within-scope runtime probe (exe; EXPECT runs)
//   SubscriptProducerProbe   — view PRODUCER as a subscript (lib; EXPECT FAILS — must be a func)
//   EscapeRejection          — negative controls: escape MUST be rejected (lib; EXPECT FAILS to compile)
//
// Self-contained (no package deps): the hypothesis is a general ~Escapable-composition
// capability, and dropping the Comparison.`Protocol` bound keeps the multi-toolchain gate
// free of the SE-0499 Comparable-vs-Escapable confound (Comparison.`Protocol` is the
// institute fork on 6.3.2 but a typealias to Swift.Comparable on 6.5-dev). Placed in
// swift-institute/Experiments/ per [EXP-022] (no package imports). crossRefs in _index.json
// link the swift-collection-primitives priors this extends.

let lifetimeSettings: [SwiftSetting] = [
    .enableExperimentalFeature("LifetimeDependence"),
    .enableExperimentalFeature("Lifetimes"),
]

let package = Package(
    name: "escapable-scoped-slice-view",
    platforms: [.macOS(.v26)],
    targets: [
        .target(
            name: "ScopedSliceKit",
            swiftSettings: lifetimeSettings
        ),
        .executableTarget(
            name: "escapable-scoped-slice-view",
            dependencies: ["ScopedSliceKit"],
            swiftSettings: lifetimeSettings
        ),
        .target(
            name: "SubscriptProducerProbe",
            dependencies: ["ScopedSliceKit"],
            swiftSettings: lifetimeSettings
        ),
        .target(
            name: "EscapeRejection",
            dependencies: ["ScopedSliceKit"],
            swiftSettings: lifetimeSettings
        ),
    ],
    swiftLanguageModes: [.v6]
)
