// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "sequence-nonmutating-test",
    platforms: [
        .macOS(.v26)
    ],
    targets: [
        .executableTarget(name: "Test")
    ],
    swiftLanguageModes: [.v6]
)
