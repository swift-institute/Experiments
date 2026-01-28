// swift-tools-version: 6.2
import PackageDescription
let package = Package(
    name: "noncopyable-protocol-workarounds",
    platforms: [.macOS(.v26)],
    targets: [.executableTarget(name: "noncopyable-protocol-workarounds")]
)
