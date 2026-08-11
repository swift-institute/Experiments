// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "nested-type-noncopyable",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .library(name: "LibraryA", targets: ["LibraryA"]),
        .library(name: "LibraryB", targets: ["LibraryB"]),
    ],
    targets: [
        // LibraryA: Defines Outer<T>.Inner nested type
        .target(name: "LibraryA"),
        // LibraryB: Uses Outer<T>.Inner with T: ~Copyable
        .target(name: "LibraryB", dependencies: ["LibraryA"]),
        .executableTarget(name: "Main", dependencies: ["LibraryA", "LibraryB"]),
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
