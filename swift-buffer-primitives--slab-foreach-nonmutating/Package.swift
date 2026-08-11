// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "slab-foreach-nonmutating",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "slab-foreach-nonmutating",
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
                .enableExperimentalFeature("AddressableTypes"),
            ]
        )
    ]
)
