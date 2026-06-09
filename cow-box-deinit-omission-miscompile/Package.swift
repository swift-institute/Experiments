// swift-tools-version: 6.3
import PackageDescription

// Minimal reproducer for a Swift 6.3.2 release-mode miscompile: after
// `isKnownUniquelyReferenced(&box)` is applied to a generic final-class box, the devirtualized
// destroy of a generic-NAMESPACE-NESTED ~Copyable struct stored in the box OMITS the struct's
// user deinit while still destroying its stored fields (elements leak; bytes are freed).
// The cross-module split (Nested lib / Repro exe) is part of the reproducing shape.
let package = Package(
    name: "cow-box-deinit-omission-miscompile",
    platforms: [.macOS(.v26)],
    targets: [
        .target(name: "Nested"),
        .executableTarget(name: "Repro", dependencies: ["Nested"]),
    ]
)
