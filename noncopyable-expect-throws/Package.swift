// swift-tools-version: 6.2
import PackageDescription
let package = Package(
    name: "noncopyable-expect-throws",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(name: "noncopyable-expect-throws"),
        .target(name: "Lib"),
        .testTarget(name: "Tests"),
        .testTarget(name: "CrossModuleTests", dependencies: ["Lib"])
    ]
)
