// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "markdown-rendering-performance-profiling",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(url: "https://github.com/swift-foundations/swift-markdown-html-render.git", branch: "main"),
        .package(url: "https://github.com/swift-foundations/swift-testing.git", branch: "main"),
    ],
    targets: [
        .testTarget(
            name: "markdown-rendering-performance-profiling",
            dependencies: [
                .product(name: "Markdown HTML Rendering", package: "swift-markdown-html-render"),
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
