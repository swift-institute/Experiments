// Status: SUPERSEDED -- pointer Equation.Protocol conformances shipped in swift-equation-primitives. (Phase 1b stale-triage 2026-04-30)
// Revalidated: Swift 6.3.1 (2026-04-30) — SUPERSEDED (per existing Status line; not re-run)
// =============================================================================
// EXPERIMENT: pointer-conformances
// QUESTION: Can we add Equation.Protocol conformances to pointer types?
// HYPOTHESIS: Need to avoid infinite recursion and handle strict memory safety
// STATUS: VERIFIED
// =============================================================================

// MARK: - Test Protocol

protocol BorrowingEquatable: ~Copyable {
    static func isEqual(_ lhs: borrowing Self, _ rhs: borrowing Self) -> Bool
}

// MARK: - V1: UnsafeRawPointer using copy + Int(bitPattern:)

extension UnsafeRawPointer: BorrowingEquatable {
    @inlinable
    static func isEqual(_ lhs: borrowing Self, _ rhs: borrowing Self) -> Bool {
        let lhsCopy = copy lhs
        let rhsCopy = copy rhs
        return Int(bitPattern: lhsCopy) == Int(bitPattern: rhsCopy)
    }
}

// MARK: - V2: UnsafeMutableRawPointer using copy + Int(bitPattern:)

extension UnsafeMutableRawPointer: BorrowingEquatable {
    @inlinable
    static func isEqual(_ lhs: borrowing Self, _ rhs: borrowing Self) -> Bool {
        let lhsCopy = copy lhs
        let rhsCopy = copy rhs
        return Int(bitPattern: lhsCopy) == Int(bitPattern: rhsCopy)
    }
}

// MARK: - V3: UnsafePointer - copy then convert to raw

extension UnsafePointer: BorrowingEquatable {
    @inlinable
    static func isEqual(_ lhs: borrowing Self, _ rhs: borrowing Self) -> Bool {
        let lhsCopy = copy lhs
        let rhsCopy = copy rhs
        return unsafe Int(bitPattern: UnsafeRawPointer(lhsCopy)) == Int(bitPattern: UnsafeRawPointer(rhsCopy))
    }
}

// MARK: - V4: UnsafeMutablePointer

extension UnsafeMutablePointer: BorrowingEquatable {
    @inlinable
    static func isEqual(_ lhs: borrowing Self, _ rhs: borrowing Self) -> Bool {
        let lhsCopy = copy lhs
        let rhsCopy = copy rhs
        return unsafe Int(bitPattern: UnsafeRawPointer(lhsCopy)) == Int(bitPattern: UnsafeRawPointer(rhsCopy))
    }
}

// MARK: - V5: UnsafeBufferPointer - use copy

extension UnsafeBufferPointer: BorrowingEquatable where Element: BorrowingEquatable {
    @inlinable
    static func isEqual(_ lhs: borrowing Self, _ rhs: borrowing Self) -> Bool {
        let lhsCopy = copy lhs
        let rhsCopy = copy rhs
        guard lhsCopy.count == rhsCopy.count else { return false }
        let lhsAddr = unsafe lhsCopy.baseAddress.map { Int(bitPattern: $0) }
        let rhsAddr = unsafe rhsCopy.baseAddress.map { Int(bitPattern: $0) }
        return lhsAddr == rhsAddr
    }
}

// MARK: - V6: UnsafeMutableBufferPointer

extension UnsafeMutableBufferPointer: BorrowingEquatable where Element: BorrowingEquatable {
    @inlinable
    static func isEqual(_ lhs: borrowing Self, _ rhs: borrowing Self) -> Bool {
        let lhsCopy = copy lhs
        let rhsCopy = copy rhs
        guard lhsCopy.count == rhsCopy.count else { return false }
        let lhsAddr = unsafe lhsCopy.baseAddress.map { Int(bitPattern: $0) }
        let rhsAddr = unsafe rhsCopy.baseAddress.map { Int(bitPattern: $0) }
        return lhsAddr == rhsAddr
    }
}

// MARK: - Test Execution

func test() {
    print("=== Testing Pointer Conformances ===\n")
    print("Build succeeded - conformances compile correctly")
    print("\n=== All tests completed ===")
}

test()
