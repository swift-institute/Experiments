// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "unmanaged-passunretained-init-di",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "unmanaged-passunretained-init-di",
            swiftSettings: [
                .strictMemorySafety(),
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
                .enableUpcomingFeature("MemberImportVisibility"),
            ]
        )
    ]
)
