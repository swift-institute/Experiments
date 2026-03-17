// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "iterative-tuple-rendering-trampoline",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "iterative-tuple-rendering-trampoline"
        )
    ]
)
