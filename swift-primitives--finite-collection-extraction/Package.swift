// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "finite-collection-extraction",
    platforms: [.macOS(.v26)],
    targets: [
        .target(name: "CoreFinite"),
        .target(name: "TypedIndex"),
        .target(name: "TypedCollection", dependencies: ["CoreFinite", "TypedIndex"]),
        .executableTarget(
            name: "finite-collection-extraction",
            dependencies: ["CoreFinite", "TypedIndex", "TypedCollection"]
        )
    ]
)
