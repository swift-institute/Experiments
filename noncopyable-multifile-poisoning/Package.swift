// swift-tools-version: 6.2
import PackageDescription
let package = Package(
    name: "noncopyable-multifile-poisoning",
    platforms: [.macOS(.v26)],
    targets: [.executableTarget(name: "noncopyable-multifile-poisoning")]
)
