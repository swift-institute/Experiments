// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "canonical-witness-capability",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "canonical-witness-capability"
        )
    ]
)
