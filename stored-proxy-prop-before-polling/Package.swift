// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "stored-proxy-prop-before-polling",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "stored-proxy-prop-before-polling",
            swiftSettings: [
                .strictMemorySafety(),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
                .enableUpcomingFeature("MemberImportVisibility"),
            ]
        )
    ]
)
