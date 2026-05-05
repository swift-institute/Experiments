// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "tagged-cross-instantiation-nested-type-ambiguity",
    platforms: [.macOS(.v26)],
    targets: [
        .target(name: "TaggedCore"),
        .target(name: "LegA", dependencies: ["TaggedCore"]),
        .target(name: "LegB", dependencies: ["TaggedCore"]),
        .executableTarget(
            name: "tagged-cross-instantiation-nested-type-ambiguity",
            dependencies: ["TaggedCore", "LegA", "LegB"]
        ),
    ]
)
