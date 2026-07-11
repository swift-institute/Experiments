// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "routing-engine-l1-composition",
    platforms: [.macOS(.v26)],
    dependencies: [
        // Spike A de-risks the swift-url-routing rebase onto the institute L1
        // parser engine. Path dependency per the experiment ground rules — an
        // experiment consumes, never edits, its dependency.
        .package(path: "../../../swift-primitives/swift-parser-primitives"),
    ],
    targets: [
        .target(
            name: "routing-engine-l1-composition",
            dependencies: [
                .product(name: "Parser Primitives", package: "swift-parser-primitives"),
            ]
        ),
        .testTarget(
            name: "routing-engine-l1-compositionTests",
            dependencies: ["routing-engine-l1-composition"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
