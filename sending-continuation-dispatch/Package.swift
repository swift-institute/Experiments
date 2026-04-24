// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "sending-continuation-dispatch",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "sending-continuation-dispatch",
            swiftSettings: [
                .strictMemorySafety(),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
                .enableUpcomingFeature("MemberImportVisibility"),
                .enableUpcomingFeature("NonisolatedNonsendingByDefault"),
            ]
        )
    ]
)
