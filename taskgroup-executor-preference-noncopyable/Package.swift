// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "taskgroup-executor-preference-noncopyable",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "taskgroup-executor-preference-noncopyable",
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
            ]
        )
    ]
)
