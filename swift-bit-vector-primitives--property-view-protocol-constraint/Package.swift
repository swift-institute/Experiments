// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "property-view-protocol-constraint",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "property-view-protocol-constraint",
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
            ]
        )
    ]
)
