// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "tagged-instant",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(url: "https://github.com/swift-primitives/swift-tagged-primitives.git", branch: "main"),
    ],
    targets: [
        .executableTarget(
            name: "tagged-instant",
            dependencies: [
                .product(name: "Tagged Primitives", package: "swift-tagged-primitives"),
            ],
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
                .enableUpcomingFeature("MemberImportVisibility"),
            ]
        )
    ]
)
