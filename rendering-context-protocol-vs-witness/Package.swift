// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "rendering-context-protocol-vs-witness",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "Variants", targets: ["Variants"]),
    ],
    targets: [
        .target(name: "Variants", path: "Sources/Variants"),
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets where ![.system, .binary, .plugin, .macro].contains(target.type) {
    let ecosystem: [SwiftSetting] = [
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
    ]
    target.swiftSettings = (target.swiftSettings ?? []) + ecosystem
}
