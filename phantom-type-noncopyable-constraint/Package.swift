// swift-tools-version: 6.2
import PackageDescription
let package = Package(
    name: "phantom-type-noncopyable-constraint",
    platforms: [.macOS(.v26)],
    targets: [.executableTarget(name: "phantom-type-noncopyable-constraint")]
)
