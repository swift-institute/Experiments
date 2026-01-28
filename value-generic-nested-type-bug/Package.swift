// swift-tools-version: 6.2
import PackageDescription
let package = Package(
    name: "value-generic-nested-type-bug",
    platforms: [.macOS(.v26)],
    targets: [.executableTarget(name: "value-generic-nested-type-bug")]
)
