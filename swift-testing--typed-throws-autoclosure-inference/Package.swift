// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "typed-throws-autoclosure-inference",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "typed-throws-autoclosure-inference",
            swiftSettings: [
                .enableUpcomingFeature("InternalImportsByDefault"),
                .enableUpcomingFeature("MemberImportVisibility"),
            ]
        )
    ]
)
