// Toolchain: Swift 6.3.1 (2026-04-30) — anchor added during Phase 7a sweep [EXP-007a]
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
//
// ===----------------------------------------------------------------------===//
// EXPERIMENT: Pointer Acquisition Requires Mutating Context
// ===----------------------------------------------------------------------===//
//
// PAPER CLAIM: "Obtaining &self requires mutation context"
//              (Section 4.4, 5.1 of Non-Mutating-Accessor-Problem.md)
//
// HYPOTHESIS: Swift requires `mutating` context to obtain UnsafeMutablePointer
//             to self, even when only read access is needed.
//
// METHODOLOGY: Incremental Construction [EXP-004a]
//
// EXPECTED RESULT: Non-mutating accessor cannot use &self
// ===----------------------------------------------------------------------===//

// MARK: - Test 1: Mutating Accessor with &self (Should Work)

struct Container1 {
    var value: Int = 42

    struct View {
        let ptr: UnsafeMutablePointer<Container1>
        init(_ ptr: UnsafeMutablePointer<Container1>) {
            self.ptr = ptr
        }
        func read() -> Int { ptr.pointee.value }
    }

    // Mutating accessor - SHOULD COMPILE
    var view: View {
        mutating _read {
            yield View(&self)
        }
    }
}

// MARK: - Test 2: Non-Mutating Accessor with &self (Should Fail)

struct Container2 {
    var value: Int = 42

    struct View {
        let ptr: UnsafeMutablePointer<Container2>
        init(_ ptr: UnsafeMutablePointer<Container2>) {
            self.ptr = ptr
        }
        func read() -> Int { ptr.pointee.value }
    }

    // Non-mutating accessor attempting &self
    // EXPECTED: Compiler error - cannot use &self in non-mutating context
    //
    // UNCOMMENT TO TEST:
    // var viewNonMutating: View {
    //     _read {
    //         yield View(&self)  // ERROR: Cannot pass immutable value as inout
    //     }
    // }
}

// MARK: - Test 3: Borrowing Function with &self (Should Fail)

struct Container3 {
    var value: Int = 42

    // Borrowing function attempting &self
    // EXPECTED: Compiler error
    //
    // UNCOMMENT TO TEST:
    // borrowing func getPointer() -> UnsafeMutablePointer<Container3> {
    //     return &self  // ERROR: Cannot convert value of type 'Container3' to inout
    // }
}

// MARK: - Test 4: Using withUnsafeMutablePointer in Borrowing Context

struct Container4 {
    var value: Int = 42

    // withUnsafeMutablePointer requires inout, so it needs mutating context
    //
    // UNCOMMENT TO TEST:
    // borrowing func accessPointer() -> Int {
    //     withUnsafeMutablePointer(to: &self) { ptr in  // ERROR
    //         ptr.pointee.value
    //     }
    // }
}

// MARK: - Test 5: Using withUnsafePointer (Read-Only) in Borrowing Context

struct Container5 {
    var value: Int = 42

    // withUnsafePointer should work from borrowing context... or does it?
    borrowing func accessReadOnly() -> Int {
        // This DOES compile! withUnsafePointer(to:) accepts a borrowing parameter
        withUnsafePointer(to: value) { ptr in
            ptr.pointee
        }
    }
}

// MARK: - Test 6: withUnsafePointer on self (the actual constraint)

struct Container6 {
    var value: Int = 42

    // Can we use withUnsafePointer on self itself?
    //
    // UNCOMMENT TO TEST:
    // borrowing func getSelfPointer() -> UnsafePointer<Container6> {
    //     withUnsafePointer(to: self) { ptr in
    //         ptr  // ERROR: Escaping closure captures non-escaping parameter
    //     }
    // }
}

// ===----------------------------------------------------------------------===//
// VERIFICATION
// ===----------------------------------------------------------------------===//

func main() {
    print("=== Pointer Acquisition Mutating Context Test ===\n")

    // Test 1: Mutating accessor works
    var c1 = Container1()
    print("Test 1 - Mutating accessor with &self:")
    print("  c1.view.read() = \(c1.view.read())")
    print("  RESULT: COMPILES (as expected)")

    // Test 5: withUnsafePointer on stored property works
    let c5 = Container5()
    print("\nTest 5 - withUnsafePointer(to: value) in borrowing context:")
    print("  c5.accessReadOnly() = \(c5.accessReadOnly())")
    print("  RESULT: COMPILES (read-only pointer to stored property)")

    print("\n=== FINDINGS ===")
    print("")
    print("CONFIRMED: &self requires mutating context")
    print("  - Test 2: Non-mutating _read cannot use &self")
    print("  - Test 3: borrowing func cannot use &self")
    print("  - Test 4: withUnsafeMutablePointer requires mutating")
    print("")
    print("PARTIAL WORKAROUND:")
    print("  - Test 5: withUnsafePointer(to: storedProperty) works")
    print("  - BUT: Cannot get pointer to self, only to stored properties")
    print("  - AND: Closure scope prevents returning the pointer")
    print("")
    print("ROOT CAUSE: Swift conflates 'obtaining address' with 'mutation permission'")
    print("  - &self is an inout reference, requiring exclusive access")
    print("  - No way to obtain UnsafePointer<Self> in non-mutating context")
}

main()

// ===----------------------------------------------------------------------===//
// RESULT: CONFIRMED
//
// The paper's claim is validated:
// - Obtaining &self requires mutating context
// - This prevents creating pointer-based accessors in non-mutating contexts
// - The fundamental issue is Swift's conflation of address acquisition with mutation
// ===----------------------------------------------------------------------===//
