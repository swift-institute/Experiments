// swift-tools-version: 6.3
//
// double-json-binary-dual-conformance — Multi-conformance probe.
//
// Hypothesis: A single Swift type (Double) can simultaneously conform
// to two sibling format-Codable protocols (JSON.Serializable and
// Binary.Serializable) without diagnostic conflicts, given that the
// two protocols have non-conflicting method signatures.
//
// Two targets per [EXP-017] cross-module validation requirement:
//
//   Probe                                — library target hosting the
//                                          Double conformances to both
//                                          protocols
//
//   double-json-binary-dual-conformance  — executable target importing
//                                          Probe + both protocol modules,
//                                          exercising Double from across
//                                          the module boundary

import PackageDescription

let package = Package(
    name: "double-json-binary-dual-conformance",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(path: "../.."),
        .package(url: "https://github.com/swift-primitives/swift-binary-primitives.git", branch: "main"),
    ],
    targets: [
        .target(
            name: "Probe",
            dependencies: [
                .product(name: "JSON", package: "swift-json"),
                .product(name: "Binary Serializable Primitives", package: "swift-binary-primitives"),
            ]
        ),
        .executableTarget(
            name: "double-json-binary-dual-conformance",
            dependencies: [
                "Probe",
                .product(name: "JSON", package: "swift-json"),
                .product(name: "Binary Serializable Primitives", package: "swift-binary-primitives"),
            ]
        ),
    ]
)
