// swift-tools-version: 6.2
import PackageDescription
let package = Package(
    name: "separate-module-conformance",
    platforms: [.macOS(.v26)],
    targets: [.executableTarget(name: "separate-module-conformance")]
)
