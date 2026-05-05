// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "init-throws-overload-disambiguation",
    platforms: [.macOS(.v26)],
    targets: [
        .target(
            name: "Definitions"
        ),
        .executableTarget(
            name: "with-spi",
            dependencies: ["Definitions"]
        ),
        .executableTarget(
            name: "without-spi",
            dependencies: ["Definitions"]
        ),
    ]
)
