// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "parameter-pack-concrete-extension",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "parameter-pack-concrete-extension"
        )
    ]
)
