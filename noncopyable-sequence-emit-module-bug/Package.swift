// swift-tools-version: 6.2
import PackageDescription
let package = Package(
    name: "noncopyable-sequence-emit-module-bug",
    platforms: [.macOS(.v26)],
    targets: [.executableTarget(name: "noncopyable-sequence-emit-module-bug")]
)
