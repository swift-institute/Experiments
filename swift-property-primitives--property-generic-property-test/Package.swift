// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "property-generic-property-test",
    platforms: [
        .macOS(.v26)
    ],
    targets: [
        .executableTarget(name: "Test")
    ],
    swiftLanguageModes: [.v6]
)
