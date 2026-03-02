// swift-tools-version: 6.2
import PackageDescription
let package = Package(
    name: "nonsending-generic-dispatch",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(name: "nonsending-generic-dispatch")
    ]
)
