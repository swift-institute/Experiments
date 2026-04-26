// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "mutator-generic-dispatch-and-keypath",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "mutator-generic-dispatch-and-keypath",
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
                .enableExperimentalFeature("SuppressedAssociatedTypes"),
            ]
        )
    ]
)
