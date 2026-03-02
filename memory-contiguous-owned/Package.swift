// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "memory-contiguous-owned",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "memory-contiguous-owned",
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
                .swiftLanguageMode(.v6),
                .enableExperimentalFeature("StrictMemorySafety"),
            ]
        )
    ]
)
