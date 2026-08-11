// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "nary-soa-feasibility",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "nary-soa-feasibility",
            swiftSettings: [
                .enableExperimentalFeature("BuiltinModule"),
                .enableExperimentalFeature("RawLayout"),
            ]
        )
    ]
)
