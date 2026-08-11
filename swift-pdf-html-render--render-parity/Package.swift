// swift-tools-version: 6.3.1
// Experiment: render-parity
// Purpose: Reproduce institute swift-pdf encoding + CSS fidelity gap.
// See Sources/render-parity/main.swift for the header (hypothesis / result / date).

import PackageDescription

let package = Package(
    name: "render-parity",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(url: "https://github.com/swift-foundations/swift-pdf.git", branch: "main"),
    ],
    targets: [
        .executableTarget(
            name: "render-parity",
            dependencies: [
                .product(name: "PDF", package: "swift-pdf"),
            ],
            swiftSettings: []
        ),
    ]
)
