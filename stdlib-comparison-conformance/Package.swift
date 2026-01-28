// swift-tools-version: 6.2
import PackageDescription
let package = Package(
    name: "stdlib-comparison-conformance",
    platforms: [.macOS(.v26)],
    targets: [.executableTarget(name: "stdlib-comparison-conformance")]
)
