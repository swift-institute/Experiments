// swift-tools-version: 6.3.1
import PackageDescription
let package = Package(
    name: "memory-lock-token-noncopyable-closure-capture",
    platforms: [.macOS(.v26)],
    targets: [.executableTarget(name: "memory-lock-token-noncopyable-closure-capture")]
)
