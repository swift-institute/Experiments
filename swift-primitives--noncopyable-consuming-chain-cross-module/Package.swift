// swift-tools-version: 6.2
import PackageDescription
let package = Package(
    name: "noncopyable-consuming-chain-cross-module",
    platforms: [.macOS(.v26)],
    targets: [
        .target(name: "StorageLib", swiftSettings: [.enableExperimentalFeature("RawLayout")]),
        .target(name: "BufferLib", dependencies: ["StorageLib"], swiftSettings: [.enableExperimentalFeature("RawLayout")]),
        .target(name: "DataStructureLib", dependencies: ["BufferLib"], swiftSettings: [.enableExperimentalFeature("RawLayout")]),
        .executableTarget(name: "Consumer", dependencies: ["DataStructureLib"], swiftSettings: [.enableExperimentalFeature("RawLayout")]),
    ]
)
