// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "sending-init-weakself-di",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "sending-init-weakself-di",
            swiftSettings: [
                .strictMemorySafety(),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
                .enableUpcomingFeature("MemberImportVisibility"),
            ]
        )
    ]
)
