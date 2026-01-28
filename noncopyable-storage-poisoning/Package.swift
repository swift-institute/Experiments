// swift-tools-version: 6.2
import PackageDescription
let package = Package(
    name: "noncopyable-storage-poisoning",
    platforms: [.macOS(.v26)],
    targets: [.executableTarget(name: "noncopyable-storage-poisoning")]
)
