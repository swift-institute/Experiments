// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "typed-throws-overload-resolution",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "typed-throws-overload-resolution",
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny"),
                .enableUpcomingFeature("InternalImportsByDefault"),
            ]
        )
    ]
)
