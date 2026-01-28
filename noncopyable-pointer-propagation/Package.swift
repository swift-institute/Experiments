// swift-tools-version: 6.2
import PackageDescription
let package = Package(
    name: "noncopyable-pointer-propagation",
    platforms: [.macOS(.v26)],
    targets: [.executableTarget(name: "noncopyable-pointer-propagation")]
)
