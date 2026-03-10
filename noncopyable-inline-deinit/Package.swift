// swift-tools-version: 6.2
import PackageDescription
let package = Package(
    name: "noncopyable-inline-deinit",
    platforms: [.macOS(.v26)],
    targets: [
        .target(name: "Lib"),
        .executableTarget(
            name: "noncopyable-inline-deinit",
            dependencies: ["Lib"]
        )
    ]
)
