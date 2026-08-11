// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "pointer-conformances",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(name: "pointer-conformances")
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
