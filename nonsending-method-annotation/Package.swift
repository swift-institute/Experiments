// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "nonsending-method-annotation",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "nonsending-method-annotation"
        )
    ]
)
