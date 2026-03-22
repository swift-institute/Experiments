// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "nonsending-clock-feasibility",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "nonsending-clock-feasibility"
        )
    ]
)
