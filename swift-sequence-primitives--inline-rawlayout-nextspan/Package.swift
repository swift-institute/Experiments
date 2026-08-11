// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "inline-rawlayout-nextspan",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "inline-rawlayout-nextspan",
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
                .enableExperimentalFeature("SuppressedAssociatedTypes"),
                .enableExperimentalFeature("RawLayout"),
                .strictMemorySafety(),
            ]
        )
    ]
)
