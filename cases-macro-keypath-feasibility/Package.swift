// swift-tools-version: 6.3
import PackageDescription
import CompilerPluginSupport

// cases-macro-keypath-feasibility
//
// Spike B (de-risks routing-arc W1): prove macro feasibility for the `@Cases`
// design's three hard parts —
//   (1) `.is(\.case)` / `.case(\.case)` keypath-literal call-site shape,
//   (2) depth-3 `@dynamicMemberLookup` case-path composition (`\.a.b.c`),
//   (3) coexistence next to another member/extension macro (the @Dual shape).
//
// Toolchain: Apple Swift 6.3.3 (plain env). Platform: macOS 26 (arm64).
// swift-syntax builds from source on first build (several minutes, expected).

let package = Package(
    name: "cases-macro-keypath-feasibility",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", "602.0.0"..<"603.0.0")
    ],
    targets: [
        // Runtime surface: minimal Case.Path<Root, Value>, the CaseAnalyzable
        // witness protocol, the `.case(...)` combinator namespaces. NOT production
        // surface — just enough to carry the spike.
        .target(name: "CasesRuntime"),

        // Macro plugin: reproduces swift-dual's enum-analysis patterns (extractCases,
        // isPublicDecl) in a minimal member+extension macro generating the per-case
        // witness type. Also a second `@DualLike` macro for the coexistence check.
        .macro(
            name: "CasesMacrosImplementation",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                .product(name: "SwiftDiagnostics", package: "swift-syntax"),
            ]
        ),

        // Public macro declarations; re-exports CasesRuntime so consumers `import CasesMacros`.
        .target(name: "CasesMacros", dependencies: ["CasesMacrosImplementation", "CasesRuntime"]),

        // Consumer module: test enums with @Cases attached (flat, nested depth-3, coexist).
        // A separate module from the tests proves cross-module keypath-literal resolution.
        .target(name: "CasesSubject", dependencies: ["CasesMacros"]),

        // Behavioral assertions (plain XCTest — no external test dep). Imports CasesSubject
        // across a module boundary: exercises every call-site shape + round-trip behavior.
        .testTarget(name: "CasesTests", dependencies: ["CasesSubject", "CasesMacros", "CasesRuntime"]),
    ],
    swiftLanguageModes: [.v6]
)
