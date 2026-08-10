// swift-tools-version:6.2

import PackageDescription

let package = Package(
    name: "equatable-crash",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "equatable-crash",
            path: ".",
            sources: ["main.swift"],
            swiftSettings: [
                .swiftLanguageMode(.v6),
            ]
        )
    ]
)
