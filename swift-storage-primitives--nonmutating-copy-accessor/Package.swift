// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "nonmutating-copy-accessor",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "nonmutating-copy-accessor",
            swiftSettings: [
                .enableExperimentalFeature("BuiltinModule"),
                .enableExperimentalFeature("Lifetimes"),
            ]
        )
    ]
)
