// swift-tools-version: 6.2
import PackageDescription
let package = Package(
    name: "HTMLRenderable",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "HTMLRenderable", targets: ["HTMLRenderable"]),
    ],
    dependencies: [
        .package(path: "../RenderingPrimitives"),
    ],
    targets: [
        .target(
            name: "HTMLRenderable",
            dependencies: [
                .product(name: "RenderingPrimitives", package: "RenderingPrimitives"),
            ],
            path: "Sources"
        ),
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
    target.swiftSettings = (target.swiftSettings ?? []) + ecosystem
}
