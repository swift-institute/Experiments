// MARK: - Generic Nested Typealias Access
// Purpose: Can consumers use `Parser.Error.Located.Protocol` for conformance,
//          constraints, and existentials — or must they use the hoisted name?
//
// Toolchain: Swift 6.2
// Platform: macOS (arm64)
//
// Result: <pending>
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
// Date: 2026-03-20

struct TestErr: Swift.Error, Sendable {}

// Test Located itself
let v1 = Parser.Error.Located(error: TestErr(), offset: 42)
requiresLocated(v1)

// Test consumer conformance
let v2 = MyError(offset: 99)
printOffset(v2)
takeAny(v2)

print("All consumer variants passed")
