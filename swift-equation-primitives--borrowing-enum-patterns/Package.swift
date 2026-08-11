// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "borrowing-enum-patterns",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(name: "borrowing-enum-patterns")
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets {
    target.swiftSettings = [
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableExperimentalFeature("Lifetimes"),
        .strictMemorySafety(),
    ]
}
