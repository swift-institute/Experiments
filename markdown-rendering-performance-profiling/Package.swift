// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "markdown-rendering-performance-profiling",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(path: "../../../swift-foundations/swift-markdown-html-rendering"),
        .package(path: "../../../swift-foundations/swift-testing"),
    ],
    targets: [
        .testTarget(
            name: "markdown-rendering-performance-profiling",
            dependencies: [
                .product(name: "Markdown HTML Rendering", package: "swift-markdown-html-rendering"),
                .product(name: "Testing", package: "swift-testing"),
            ]
        ),
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
