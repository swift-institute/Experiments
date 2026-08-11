// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "lazy-iterator-nextspan-strategies",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "lazy-iterator-nextspan-strategies",
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
                .enableExperimentalFeature("SuppressedAssociatedTypes"),
            ]
        )
    ]
)
