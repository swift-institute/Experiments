// MARK: - V3: internal raw at L2; sibling target via @testable import
// Purpose: Raw FFI lives at internal access. A sibling target (test or
// benchmark) reaches it via `@testable import V3_L2`. V3_L2 must be
// compiled with `-enable-testing` for @testable to work in any mode.
//
// Note: -enable-testing carries optimization implications (some
// optimizations disabled to preserve symbol visibility for testing).

public struct Descriptor: ~Copyable {
    public let _rawValue: Int32

    public init(_rawValue: Int32) {
        self._rawValue = _rawValue
    }
}
