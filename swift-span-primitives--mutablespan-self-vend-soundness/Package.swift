// swift-tools-version: 6.3
import PackageDescription

// Experiment: mutablespan-self-vend-soundness
// [EXP-017] soundness spike for the mutable linchpin: does a bare `Swift.MutableSpan`,
// conforming to the mutable span-vending capability by vending ITSELF
// (`mutableSpan { mutating get { self } }`, requiring `~Escapable` restated on the
// protocol), alias its backing storage soundly — cross-module AND in release mode?

let package = Package(
    name: "mutablespan-self-vend-soundness",
    platforms: [.macOS(.v26)],
    targets: [
        // The mutable capability protocol (with ~Escapable restated) + the MutableSpan linchpin.
        .target(name: "MutableLinchpin"),
        // Cross-module consumer: mutate a bare MutableSpan THROUGH the capability, verify aliasing.
        .executableTarget(
            name: "mutablespan-self-vend-soundness",
            dependencies: ["MutableLinchpin"]
        ),
    ],
    swiftLanguageModes: [.v6]
)

for target in package.targets {
    target.swiftSettings = (target.swiftSettings ?? []) + [
        .enableExperimentalFeature("Lifetimes"),
        .enableExperimentalFeature("SuppressedAssociatedTypes"),
    ]
}
