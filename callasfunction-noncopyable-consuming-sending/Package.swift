// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "callasfunction-noncopyable-consuming-sending",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "callasfunction-noncopyable-consuming-sending",
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
            ]
        )
    ]
)
