// swift-tools-version: 6.2
import PackageDescription
let package = Package(
    name: "RenderingPrimitives",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "RenderingPrimitives", targets: ["RenderingPrimitives"]),
    ],
    targets: [
        .target(name: "RenderingPrimitives", path: "Sources"),
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
