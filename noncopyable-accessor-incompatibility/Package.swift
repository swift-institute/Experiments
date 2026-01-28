// swift-tools-version: 6.2
import PackageDescription
let package = Package(
    name: "noncopyable-accessor-incompatibility",
    platforms: [.macOS(.v26)],
    targets: [.executableTarget(name: "noncopyable-accessor-incompatibility")]
)
