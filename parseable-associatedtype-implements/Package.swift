// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "parseable-associatedtype-implements",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "parseable-associatedtype-implements"
        )
    ]
)
