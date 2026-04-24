// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "mutex-coroutine-rawlayout",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "mutex-coroutine-rawlayout",
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
                .enableExperimentalFeature("RawLayout"),
            ]
        )
    ]
)
