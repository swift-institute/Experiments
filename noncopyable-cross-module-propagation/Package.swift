// swift-tools-version: 6.2
import PackageDescription
let package = Package(
    name: "noncopyable-cross-module-propagation",
    platforms: [.macOS(.v26)],
    targets: [
        .target(name: "Lib"),
        .executableTarget(name: "noncopyable-cross-module-propagation", dependencies: ["Lib"])
    ]
)
