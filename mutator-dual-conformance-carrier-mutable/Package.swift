// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "mutator-dual-conformance-carrier-mutable",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "mutator-dual-conformance-carrier-mutable",
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
                .enableExperimentalFeature("SuppressedAssociatedTypes"),
            ]
        )
    ]
)
