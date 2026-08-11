// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "contiguous-protocol-conformance",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "contiguous-protocol-conformance",
            swiftSettings: [
                .enableExperimentalFeature("RawLayout"),
                .enableExperimentalFeature("Lifetimes"),
                .strictMemorySafety()
            ]
        )
    ]
)
