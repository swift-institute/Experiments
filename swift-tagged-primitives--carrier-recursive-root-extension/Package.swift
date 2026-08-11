// swift-tools-version: 6.3.1
import PackageDescription

let package = Package(
    name: "carrier-recursive-root-extension",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "carrier-recursive-root-extension"
        )
    ]
)
