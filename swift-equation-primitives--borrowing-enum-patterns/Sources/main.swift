// Status: SUPERSEDED -- BorrowingEquatable + copy-keyword pattern shipped in swift-equation-primitives. (Phase 1b stale-triage 2026-04-30)
// Revalidated: Swift 6.3.1 (2026-04-30) — SUPERSEDED (per existing Status line; not re-run)
// =============================================================================
// EXPERIMENT: borrowing-enum-patterns
// QUESTION: Can we pattern match on borrowed enum values (Optional, Result)?
// HYPOTHESIS: We can use `copy` to make copies of Copyable borrowed values
// STATUS: VERIFIED
// RESULT: SUCCESS - `copy` keyword enables pattern matching on borrowed values
// APPLIED: Conditional conformances added to equation-primitives
// =============================================================================

// MARK: - Test Protocol

protocol BorrowingEquatable: ~Copyable {
    static func isEqual(_ lhs: borrowing Self, _ rhs: borrowing Self) -> Bool
}

// MARK: - V1: Use `copy` keyword to copy borrowed Copyable values

extension Optional: BorrowingEquatable where Wrapped: BorrowingEquatable, Wrapped: Copyable {
    static func isEqual(_ lhs: borrowing Self, _ rhs: borrowing Self) -> Bool {
        // Copy the borrowed values since Optional<Wrapped> is Copyable when Wrapped is Copyable
        let lhsCopy = copy lhs
        let rhsCopy = copy rhs
        switch lhsCopy {
        case .none:
            switch rhsCopy {
            case .none: return true
            case .some: return false
            }
        case let .some(l):
            switch rhsCopy {
            case .none: return false
            case let .some(r): return Wrapped.isEqual(l, r)
            }
        }
    }
}

// MARK: - V2: Result with copy

extension Result: BorrowingEquatable where Success: BorrowingEquatable & Copyable, Failure: BorrowingEquatable & Copyable {
    static func isEqual(_ lhs: borrowing Self, _ rhs: borrowing Self) -> Bool {
        let lhsCopy = copy lhs
        let rhsCopy = copy rhs
        switch lhsCopy {
        case let .success(l):
            switch rhsCopy {
            case let .success(r): return Success.isEqual(l, r)
            case .failure: return false
            }
        case let .failure(l):
            switch rhsCopy {
            case .success: return false
            case let .failure(r): return Failure.isEqual(l, r)
            }
        }
    }
}

// MARK: - V3: Array - no copy needed, iteration works

extension Array: BorrowingEquatable where Element: BorrowingEquatable {
    static func isEqual(_ lhs: borrowing Self, _ rhs: borrowing Self) -> Bool {
        guard lhs.count == rhs.count else { return false }
        for (l, r) in zip(lhs, rhs) {
            if !Element.isEqual(l, r) { return false }
        }
        return true
    }
}

// MARK: - Test Conformances

extension Int: BorrowingEquatable {
    static func isEqual(_ lhs: borrowing Self, _ rhs: borrowing Self) -> Bool {
        lhs == rhs
    }
}

extension String: BorrowingEquatable {
    static func isEqual(_ lhs: borrowing Self, _ rhs: borrowing Self) -> Bool {
        lhs == rhs
    }
}

struct SimpleError: Error, BorrowingEquatable {
    let code: Int
    static func isEqual(_ lhs: borrowing Self, _ rhs: borrowing Self) -> Bool {
        lhs.code == rhs.code
    }
}

// MARK: - Test Execution

func test() {
    print("=== Testing BorrowingEquatable with copy ===\n")

    // V1: Optional
    print("V1 Optional (with copy):")
    let opt1: Int? = 42
    let opt2: Int? = 42
    let opt3: Int? = 99
    let opt4: Int? = nil
    print("  Some(42) == Some(42): \(Optional.isEqual(opt1, opt2))")
    print("  Some(42) == Some(99): \(Optional.isEqual(opt1, opt3))")
    print("  Some(42) == nil: \(Optional.isEqual(opt1, opt4))")
    print("  nil == nil: \(Optional.isEqual(opt4, opt4))")

    // V2: Result
    print("\nV2 Result (with copy):")
    let res1: Result<Int, SimpleError> = .success(42)
    let res2: Result<Int, SimpleError> = .success(42)
    let res3: Result<Int, SimpleError> = .success(99)
    let res4: Result<Int, SimpleError> = .failure(SimpleError(code: 1))
    let res5: Result<Int, SimpleError> = .failure(SimpleError(code: 1))
    print("  success(42) == success(42): \(Result.isEqual(res1, res2))")
    print("  success(42) == success(99): \(Result.isEqual(res1, res3))")
    print("  success(42) == failure(1): \(Result.isEqual(res1, res4))")
    print("  failure(1) == failure(1): \(Result.isEqual(res4, res5))")

    // V3: Array
    print("\nV3 Array (for loop, no copy needed):")
    let arr1 = [1, 2, 3]
    let arr2 = [1, 2, 3]
    let arr3 = [1, 2, 4]
    let arr4 = [1, 2]
    print("  [1,2,3] == [1,2,3]: \(Array.isEqual(arr1, arr2))")
    print("  [1,2,3] == [1,2,4]: \(Array.isEqual(arr1, arr3))")
    print("  [1,2,3] == [1,2]: \(Array.isEqual(arr1, arr4))")

    print("\n=== All tests completed ===")
}

test()
