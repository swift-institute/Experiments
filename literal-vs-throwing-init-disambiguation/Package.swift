// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "literal-vs-throwing-init-disambiguation",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "literal-vs-throwing-init-disambiguation"
        )
    ]
)
