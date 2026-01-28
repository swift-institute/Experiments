// swift-tools-version: 6.2
import PackageDescription
let package = Package(
    name: "nested-generic-performance",
    platforms: [.macOS(.v26)],
    targets: [.executableTarget(name: "nested-generic-performance")]
)
