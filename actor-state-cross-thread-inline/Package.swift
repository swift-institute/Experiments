// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "actor-state-cross-thread-inline",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "actor-state-cross-thread-inline",
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
                .unsafeFlags(["-Xllvm", "-sil-disable-pass=CopyPropagation"], .when(configuration: .release)),
            ]
        )
    ]
)
