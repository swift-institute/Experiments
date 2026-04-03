// swift-tools-version: 6.2
import PackageDescription
let package = Package(
    name: "noncopyable-constraint-behavior",
    platforms: [.macOS(.v26)],
    targets: [
        .target(name: "CrossModuleLib", path: "Sources/CrossModuleLib"),
        .target(
            name: "noncopyable-constraint-behavior",
            dependencies: ["CrossModuleLib"],
            path: "Sources/noncopyable-constraint-behavior"
        )
    ]
)
