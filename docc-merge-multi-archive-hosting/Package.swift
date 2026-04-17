// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "docc-merge-multi-archive-hosting",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "docc-merge-multi-archive-hosting"
        )
    ]
)
