// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "borrow-consume-extract",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "borrow-consume-extract"
        )
    ]
)
