// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "exported-import-name-shadowing",
    platforms: [.macOS(.v26)],
    targets: [
        // --- Library Modules ---

        // Defines a custom Array<Element> that shadows Swift.Array
        .target(name: "Core", path: "Sources/Core"),

        // Re-exports Core via @_exported (mirrors Array_Primitives pattern)
        .target(name: "Umbrella", dependencies: ["Core"], path: "Sources/Umbrella"),

        // Re-exports Core via @_exported AND adds a typealias (proposed fix)
        .target(name: "UmbrellaTypealias", dependencies: ["Core"], path: "Sources/UmbrellaTypealias"),

        // --- Consumer Executables ---

        // Scenario 1: Consumer imports Umbrella (@_exported chain)
        .executableTarget(name: "Baseline", dependencies: ["Umbrella"], path: "Sources/Baseline"),

        // Scenario 2: Consumer imports Core directly
        .executableTarget(name: "DirectImport", dependencies: ["Core"], path: "Sources/DirectImport"),

        // Scenario 3: Consumer imports UmbrellaTypealias (proposed fix)
        .executableTarget(name: "TypealiasFix", dependencies: ["UmbrellaTypealias"], path: "Sources/TypealiasFix"),

        // --- Additional Library Modules (deeper chains) ---

        // Re-exports Umbrella (mirrors Graph_Primitives_Core re-exporting Array_Primitives)
        .target(name: "MiddleLayer", dependencies: ["Umbrella"], path: "Sources/MiddleLayer"),

        // Two independent modules that both re-export Core
        .target(name: "SiblingA", dependencies: ["Core"], path: "Sources/SiblingA"),
        .target(name: "SiblingB", dependencies: ["Core"], path: "Sources/SiblingB"),

        // --- Additional Consumer Executables ---

        // Scenario 4: Deep chain (3 levels of @_exported)
        .executableTarget(name: "DeepChain", dependencies: ["MiddleLayer"], path: "Sources/DeepChain"),

        // Scenario 5: Two modules both re-exporting Core
        .executableTarget(name: "MultiPath", dependencies: ["SiblingA", "SiblingB"], path: "Sources/MultiPath"),

        // Scenario 6: Edge cases — [T] sugar, conformances, literals
        .executableTarget(name: "EdgeCases", dependencies: ["Umbrella"], path: "Sources/EdgeCases"),

        // Scenario 7: Type identity verification
        .executableTarget(name: "TypeIdentity", dependencies: ["Umbrella"], path: "Sources/TypeIdentity"),
    ]
)
