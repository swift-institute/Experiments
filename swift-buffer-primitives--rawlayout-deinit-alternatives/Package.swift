// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "rawlayout-deinit-alternatives",
    platforms: [.macOS(.v26)],
    targets: [
        // V01: discard self — trivially-destructible storage only
        .executableTarget(
            name: "V01-discard-self",
            swiftSettings: [
                .enableExperimentalFeature("RawLayout"),
            ]
        ),

        // V02: Guard idempotence — reference-type guard patterns
        .executableTarget(
            name: "V02-guard-idempotence",
            swiftSettings: [
                .enableExperimentalFeature("RawLayout"),
            ]
        ),

        // V03: Escapable lifetime — @_unsafeNonescapableResult in deinit
        .executableTarget(
            name: "V03-escapable-lifetime",
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
                .strictMemorySafety(),
            ]
        ),

        // V04: Slab bitmap cleanup — documentation only (no compilable reproduction)
        // Cannot reproduce MoveOnlyChecker crash outside production context.
        // See EXPERIMENT.md V04 section for documented workaround.
    ],
    swiftLanguageModes: [.v6]
)
