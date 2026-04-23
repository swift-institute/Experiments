// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "ownership-borrow-protocol-unification",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "ownership-borrow-protocol-unification",
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
                .enableExperimentalFeature("SuppressedAssociatedTypes"),
            ]
        )
    ]
)
