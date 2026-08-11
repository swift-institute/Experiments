// swift-tools-version: 6.2
import PackageDescription

// Two-module experiment: simulates identity-primitives (no conformance) +
// downstream consumer package that wants to add literal conformance for
// specific Tagged specializations.
let package = Package(
    name: "tagged-literal-consumer-opt-in",
    platforms: [.macOS(.v26)],
    targets: [
        // "Library A" — simulates identity-primitives: declares Tagged,
        // DOES NOT declare ExpressibleByIntegerLiteral conformance.
        .target(
            name: "TaggedLib"
        ),
        // "Consumer 1" — adds literal conformance for its specific Tagged<Tag, Raw>.
        .target(
            name: "ConsumerA",
            dependencies: ["TaggedLib"]
        ),
        // "Consumer 2" — also wants literal conformance for a different Tagged<Tag, Raw>.
        // Does Swift reject this because ConsumerA already added one?
        .target(
            name: "ConsumerB",
            dependencies: ["TaggedLib"]
        ),
        // Client that imports both — does conflict surface here?
        // Default client: imports TaggedLib + ConsumerA only.
        // ConsumerA's conformance works in isolation — compiles and runs.
        .executableTarget(
            name: "tagged-literal-consumer-opt-in",
            dependencies: ["TaggedLib", "ConsumerA"]
        )
    ]
)
