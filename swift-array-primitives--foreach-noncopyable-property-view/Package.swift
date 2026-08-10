// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "foreach-noncopyable-property-view",
    targets: [
        .executableTarget(name: "Test", path: "Sources")
    ],
    swiftLanguageModes: [.v6]
)
