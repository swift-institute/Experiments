// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "generic-vector-bit-substrate",
    platforms: [.macOS(.v26)],
    products: [
        .executable(name: "generic-vector-bit-substrate", targets: ["generic-vector-bit-substrate"])
    ],
    targets: [
        .executableTarget(
            name: "generic-vector-bit-substrate",
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        )
    ]
)
