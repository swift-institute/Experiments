// MARK: - Nested Package Source Ownership
// Purpose: Verify SwiftPM lets a parent package claim sources from a directory
//          that contains a nested Package.swift, when the parent uses an
//          explicit `path:` in its testTarget declaration.
//
// Toolchain: Swift 6.2 (per RESULTS.md)
// Revalidated: Swift 6.3.1 (2026-04-17) — PASSES (parent Lib + nested test packages all build clean; the explicit `path:` override of SwiftPM's "ignore directories with Package.swift" rule still works)
// Platform: macOS 26 (arm64)
// Result: CONFIRMED — see RESULTS.md.

public func greet() -> String {
    "Hello from Lib"
}
