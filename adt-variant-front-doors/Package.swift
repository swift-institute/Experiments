// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "adt-variant-front-doors",
    platforms: [.macOS(.v26)],
    targets: [
        // Library target — the carrier + columns + front-door aliases.
        .target(
            name: "FrontDoors",
            swiftSettings: [.enableExperimentalFeature("SuppressedAssociatedTypes")]
        ),
        // Consumer target — exercises the ALIAS spellings across a module boundary ([EXP-017]).
        .executableTarget(
            name: "client",
            dependencies: ["FrontDoors"],
            swiftSettings: [.enableExperimentalFeature("SuppressedAssociatedTypes")]
        ),
    ]
)
