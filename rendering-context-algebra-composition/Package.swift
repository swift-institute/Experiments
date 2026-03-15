// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "rendering-context-algebra-composition",
    platforms: [.macOS(.v26)],
    targets: [
        .target(
            name: "Variants",
            path: "Sources/Variants"
        ),
        .testTarget(
            name: "Composition Tests",
            dependencies: ["Variants"],
            path: "Tests/Composition Tests"
        ),
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    target.swiftSettings = (target.swiftSettings ?? []) + [
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    ]
}
