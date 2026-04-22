// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "unapplied-init-literal-inference-footgun",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "unapplied-init-literal-inference-footgun"
        )
    ]
)
