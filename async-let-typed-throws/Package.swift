// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "async-let-typed-throws",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "async-let-typed-throws"
        )
    ]
)
