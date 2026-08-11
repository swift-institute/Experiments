// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "protocol-extension-layer-visibility",
    platforms: [.macOS(.v26)],
    targets: [
        // Module A: Defines Vector, VectorProtocol, Ordinal (with throwing init), Cardinal (with .one)
        .target(
            name: "BaseTypes",
            path: "Sources/BaseTypes"
        ),
        // Module B: Imports BaseTypes, adds .one via protocol extension
        .target(
            name: "AlgebraExtension",
            dependencies: ["BaseTypes"],
            path: "Sources/AlgebraExtension"
        ),
        // Variant 1: Only BaseTypes imported — Ordinal(.one) should be unambiguous (non-throwing)
        .executableTarget(
            name: "variant-affine-only",
            dependencies: ["BaseTypes"],
            path: "Sources/variant-affine-only"
        ),
        // Variant 2: AlgebraExtension imported — Vector.one should work
        .executableTarget(
            name: "variant-algebra",
            dependencies: ["AlgebraExtension"],
            path: "Sources/variant-algebra"
        ),
        // Module C: Adds .one as DIRECT member on Vector (simulates current production hazard)
        .target(
            name: "DirectOneModule",
            dependencies: ["BaseTypes"],
            path: "Sources/DirectOneModule"
        ),
        // Variant 3: Direct member .one — proves the hazard exists with direct members (control)
        .executableTarget(
            name: "variant-direct-member",
            dependencies: ["DirectOneModule"],
            path: "Sources/variant-direct-member"
        ),
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    let settings: [SwiftSetting] = [
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableExperimentalFeature("Lifetimes"),
        .strictMemorySafety()
    ]
    target.swiftSettings = (target.swiftSettings ?? []) + settings
}
