// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "associatedtype-output-collision",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "associatedtype-output-collision",
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
                .enableUpcomingFeature("MemberImportVisibility"),
            ]
        )
    ],
    swiftLanguageModes: [.v6]
)
