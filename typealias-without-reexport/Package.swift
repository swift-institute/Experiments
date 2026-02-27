// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "typealias-without-reexport",
    platforms: [.macOS(.v26)],
    targets: [
        // Simulates String_Primitives: declares a top-level `String` type
        .target(
            name: "StringLike",
            path: "Sources/StringLike"
        ),
        // Simulates Kernel_Primitives: imports StringLike WITHOUT @_exported,
        // exposes it only through a namespaced typealias
        .target(
            name: "KernelLike",
            dependencies: ["StringLike"],
            path: "Sources/KernelLike"
        ),
        // Simulates downstream consumer: imports KernelLike,
        // tests whether bare `String` resolves to Swift.String
        .executableTarget(
            name: "Consumer",
            dependencies: ["KernelLike", "StringLike"],
            path: "Sources/Consumer"
        ),
    ]
)

for target in package.targets {
    target.swiftSettings = (target.swiftSettings ?? []) + [
        .strictMemorySafety(),
        .enableUpcomingFeature("InternalImportsByDefault"),
        .enableUpcomingFeature("MemberImportVisibility"),
        .enableExperimentalFeature("Lifetimes"),
    ]
}
