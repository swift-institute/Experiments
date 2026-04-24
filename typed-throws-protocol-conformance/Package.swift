// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "typed-throws-protocol-conformance",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "typed-throws-protocol-conformance"
        )
    ]
)
