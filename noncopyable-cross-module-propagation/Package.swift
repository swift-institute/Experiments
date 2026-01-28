// swift-tools-version: 6.2
import PackageDescription
let package = Package(
    name: "noncopyable-cross-module-propagation",
    platforms: [.macOS(.v26)],
    targets: [.executableTarget(name: "noncopyable-cross-module-propagation")]
)
