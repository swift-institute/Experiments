// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "atexit-testing-runner-lifecycle",
    platforms: [.macOS(.v26)],
    targets: [
        .testTarget(
            name: "atexit-testing-runner-lifecycle",
            path: "Tests/atexit-testing-runner-lifecycle"
        )
    ]
)
