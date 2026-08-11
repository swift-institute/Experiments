// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "typed-throws-error-alias",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(name: "typed-throws-error-alias")
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets {
    target.swiftSettings = [
        .enableUpcomingFeature("ExistentialAny"),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableExperimentalFeature("Lifetimes"),
        .strictMemorySafety()
    ]
}
