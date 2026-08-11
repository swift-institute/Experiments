// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "static-property-view-pattern",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "static-property-view-pattern",
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
            ]
        )
    ]
)
