// swift-tools-version: 6.2
import PackageDescription
let package = Package(
    name: "for-loop-result-builder",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(path: "LocalPackages/RenderingPrimitives"),
        .package(path: "LocalPackages/HTMLRenderable"),
    ],
    targets: [
        .executableTarget(
            name: "for-loop-result-builder",
            dependencies: [
                .product(name: "RenderingPrimitives", package: "RenderingPrimitives"),
                .product(name: "HTMLRenderable", package: "HTMLRenderable"),
            ],
            path: "Sources"
        )
    ]
)

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    let ecosystem: [SwiftSetting] = [
        .strictMemorySafety(),
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
        .enableExperimentalFeature("Lifetimes"),
        .enableExperimentalFeature("SuppressedAssociatedTypes"),
        .enableExperimentalFeature("SuppressedAssociatedTypesWithDefaults"),
    ]

    let package: [SwiftSetting] = []

    target.swiftSettings = (target.swiftSettings ?? []) + ecosystem + package
}
