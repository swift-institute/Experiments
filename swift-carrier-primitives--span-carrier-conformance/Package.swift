// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "span-carrier-conformance",
    platforms: [.macOS(.v26)],
    targets: [
        .target(
            name: "SpanCarrier",
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
                .enableExperimentalFeature("SuppressedAssociatedTypes"),
            ]
        ),
        .executableTarget(
            name: "span-carrier-conformance",
            dependencies: ["SpanCarrier"],
            swiftSettings: [
                .enableExperimentalFeature("Lifetimes"),
                .enableExperimentalFeature("SuppressedAssociatedTypes"),
            ]
        ),
    ]
)
