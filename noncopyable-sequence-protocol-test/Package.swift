// swift-tools-version: 6.2
import PackageDescription
let package = Package(
    name: "noncopyable-sequence-protocol-test",
    platforms: [.macOS(.v26)],
    targets: [.executableTarget(name: "noncopyable-sequence-protocol-test")]
)
