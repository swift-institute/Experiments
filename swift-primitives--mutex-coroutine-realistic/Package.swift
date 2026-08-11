// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "mutex-coroutine-realistic",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "mutex-coroutine-realistic",
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
            ]
        )
    ]
)
