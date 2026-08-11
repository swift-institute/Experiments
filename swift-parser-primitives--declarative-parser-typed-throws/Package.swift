// Toolchain: Swift 6.3.1 (2026-04-30) — anchor added during Phase 7a sweep [EXP-007a]
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
//
// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "declarative-parser-typed-throws",
    platforms: [.macOS(.v26)],
    dependencies: [
        .package(path: "../../"),
    ],
    targets: [
        .testTarget(
            name: "declarative-parser-typed-throws",
            dependencies: [
                .product(name: "Parser Primitives", package: "swift-parser-primitives"),
            ],
            path: "Tests/declarative-parser-typed-throws"
        )
    ]
)
