// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "stored-property-span-access",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "stored-property-span-access",
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
                .enableExperimentalFeature("SuppressedAssociatedTypes"),
                .strictMemorySafety(),
            ]
        )
    ]
)
