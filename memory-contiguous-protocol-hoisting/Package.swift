// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "memory-contiguous-protocol-hoisting",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "memory-contiguous-protocol-hoisting",
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
                .swiftLanguageMode(.v6),
                .enableExperimentalFeature("StrictMemorySafety"),
                .enableExperimentalFeature("SuppressedAssociatedTypes"),
            ]
        )
    ]
)
