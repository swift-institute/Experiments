// swift-tools-version: 6.3
import PackageDescription

// Experiment: span-typealias-hosting
// Validates making the package's top-level `Span` a typealias to `Swift.Span`
// (resolving the namespace/stdlib collision) and re-hosting the capability
// protocols via the "hosting + typealias" technique. Two library modules carry
// the competing designs; the executable is the cross-module consumer.

let package = Package(
    name: "span-typealias-hosting",
    platforms: [.macOS(.v26)],
    targets: [
        // UnboundAlias — the validated fix: `typealias Span = Swift.Span` + hoisted
        // declarations surfaced as Element-free member typealiases. Bare Span.Protocol works.
        .target(name: "UnboundAlias"),
        // BoundAlias — the cautionary variant: `typealias Span<E> = Swift.Span<E>`. Bare
        // Span.Protocol FAILS; only the specialized `Span<E>.Protocol` resolves. Built to
        // prove it compiles specialized; NOT imported by the consumer (its `Swift.Span.Protocol`
        // member typealias would collide with UnboundAlias's).
        .target(name: "BoundAlias"),
        // Cross-module consumer: imports UnboundAlias, conforms a type and runs a generic
        // algorithm using the BARE spellings.
        .executableTarget(
            name: "span-typealias-hosting",
            dependencies: ["UnboundAlias"]
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
