// swift-tools-version: 6.2
import PackageDescription
let package = Package(
    name: "noncopyable-associatedtype-domain",
    platforms: [.macOS(.v26)],
    targets: [.executableTarget(name: "noncopyable-associatedtype-domain")]
)
