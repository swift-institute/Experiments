// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "path-operator-overload-resolution",
    platforms: [.macOS(.v26)],
    targets: [
        .target(
            name: "PathOverloadExperiment",
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
        .testTarget(
            name: "PathOverloadExperimentTests",
            dependencies: ["PathOverloadExperiment"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        ),
    ]
)
