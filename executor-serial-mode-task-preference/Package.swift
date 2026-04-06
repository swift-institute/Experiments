// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "executor-serial-mode-task-preference",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "executor-serial-mode-task-preference"
        )
    ]
)
