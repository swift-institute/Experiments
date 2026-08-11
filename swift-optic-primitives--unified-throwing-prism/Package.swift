// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "unified-throwing-prism",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "unified-throwing-prism",
            swiftSettings: [
                .strictMemorySafety(),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
                .enableUpcomingFeature("MemberImportVisibility"),
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
