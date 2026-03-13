// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "member-import-visibility-reexport",
    platforms: [.macOS(.v26)],
    targets: [
        .target(name: "Upstream"),
        .target(
            name: "Reexporter",
            dependencies: ["Upstream"]
        ),
        .executableTarget(
            name: "Consumer",
            dependencies: ["Reexporter"],
            swiftSettings: [
                .enableUpcomingFeature("MemberImportVisibility"),
            ]
        ),
    ]
)
