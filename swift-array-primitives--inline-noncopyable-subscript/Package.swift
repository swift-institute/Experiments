// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "inline-noncopyable-subscript",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "inline-noncopyable-subscript",
            swiftSettings: [
                .enableExperimentalFeature("BuiltinModule"),
                .enableExperimentalFeature("Lifetimes"),
            ]
        )
    ]
)
