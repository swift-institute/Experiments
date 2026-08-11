// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "builtin-address-of-borrow",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(name: "builtin-address-of-borrow")
    ]
)
