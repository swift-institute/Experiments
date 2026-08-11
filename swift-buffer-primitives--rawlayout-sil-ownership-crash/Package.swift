// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "rawlayout-sil-ownership-crash",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(url: "https://github.com/swift-primitives/swift-storage-primitives.git", branch: "main"),
    ],
    targets: [
        // V01: CopyPropagation crash — ~Copyable enum payload consumption
        .target(
            name: "V01-copy-propagation-lib",
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
                .enableUpcomingFeature("MemberImportVisibility"),
            ]
        ),
        .executableTarget(
            name: "V01-copy-propagation",
            dependencies: ["V01-copy-propagation-lib"],
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
                .enableUpcomingFeature("MemberImportVisibility"),
            ]
        ),

        // V02: Enum _modify — language limitation (8 variants)
        .executableTarget(
            name: "V02-enum-modify",
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
                .strictMemorySafety(),
            ]
        ),

        // V03: Enum _modify recovery — heap pointer bypass + inline spill
        .executableTarget(
            name: "V03-enum-modify-recovery",
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
                .strictMemorySafety(),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
