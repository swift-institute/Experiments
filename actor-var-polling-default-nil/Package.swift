// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "actor-var-polling-default-nil",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "actor-var-polling-default-nil",
            swiftSettings: [
                .strictMemorySafety(),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
                .enableUpcomingFeature("MemberImportVisibility"),
            ]
        )
    ]
)
