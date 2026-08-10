// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "shorthand-syntax-with-shadowing",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "shorthand-syntax-with-shadowing"
        )
    ]
)
