// Toolchain: Swift 6.3.1 (2026-04-30) — anchor added during Phase 7a sweep [EXP-007a]
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
//
// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "atexit-testing-runner-lifecycle",
    platforms: [.macOS(.v26)],
    targets: [
        .testTarget(
            name: "atexit-testing-runner-lifecycle",
            path: "Tests/atexit-testing-runner-lifecycle"
        )
    ]
)
