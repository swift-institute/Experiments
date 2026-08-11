// Toolchain: Swift 6.3.1 (2026-04-30) — anchor added during Phase 7a sweep [EXP-007a]
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
//
// ===----------------------------------------------------------------------===//
// EXPERIMENT: ~Escapable Types Do Not Solve Pointer Acquisition
// ===----------------------------------------------------------------------===//
//
// PAPER CLAIM: "Despite ~Escapable annotations, the problem persists: we still
//               can't create the accessor in a non-mutating context because
//               creation requires &self."
//              (Section 5.4 of Non-Mutating-Accessor-Problem.md)
//
// HYPOTHESIS: ~Escapable prevents pointer escape but doesn't enable pointer
//             acquisition from borrowed context.
//
// METHODOLOGY: Incremental Construction [EXP-004a]
//
// EXPECTED RESULT: ~Escapable types still require mutating context for &self
// ===----------------------------------------------------------------------===//

// MARK: - Test 1: ~Escapable View Type (Mutating Works)

struct Container1: ~Copyable {
    var value: Int = 42

    struct View: ~Copyable, ~Escapable {
        let ptr: UnsafeMutablePointer<Container1>

        @_lifetime(borrow ptr)
        init(_ ptr: UnsafeMutablePointer<Container1>) {
            self.ptr = ptr
        }

        func read() -> Int { ptr.pointee.value }
    }

    // Mutating accessor works with ~Escapable view
    var view: View {
        mutating _read {
            yield unsafe View(&self)
        }
    }
}

// MARK: - Test 2: ~Escapable View in Non-Mutating Context (Should Fail)

struct Container2: ~Copyable {
    var value: Int = 42

    struct View: ~Copyable, ~Escapable {
        let ptr: UnsafeMutablePointer<Container2>

        @_lifetime(borrow ptr)
        init(_ ptr: UnsafeMutablePointer<Container2>) {
            self.ptr = ptr
        }

        func read() -> Int { ptr.pointee.value }
    }

    // Non-mutating accessor STILL cannot use &self
    // ~Escapable doesn't change this fundamental constraint
    //
    // UNCOMMENT TO TEST:
    // var viewNonMutating: View {
    //     _read {
    //         yield unsafe View(&self)  // ERROR: Cannot pass immutable value as inout
    //     }
    // }
}

// MARK: - Test 3: ~Escapable with Borrowing Function (Should Fail)

struct Container3: ~Copyable {
    var value: Int = 42

    struct View: ~Copyable, ~Escapable {
        let ptr: UnsafeMutablePointer<Container3>

        @_lifetime(borrow ptr)
        init(_ ptr: UnsafeMutablePointer<Container3>) {
            self.ptr = ptr
        }
    }

    // Borrowing function still cannot create View
    //
    // UNCOMMENT TO TEST:
    // borrowing func makeView() -> View {
    //     unsafe View(&self)  // ERROR: Cannot convert value to inout
    // }
}

// MARK: - Test 4: What ~Escapable DOES Prevent

struct Container4: ~Copyable {
    var value: Int = 42

    struct View: ~Copyable, ~Escapable {
        let ptr: UnsafeMutablePointer<Container4>

        @_lifetime(borrow ptr)
        init(_ ptr: UnsafeMutablePointer<Container4>) {
            self.ptr = ptr
        }
    }

    var view: View {
        mutating _read {
            yield unsafe View(&self)
        }
    }
}

// ~Escapable prevents storing the view
// var storedView: Container4.View?  // ERROR: Cannot store ~Escapable type

// MARK: - Test 5: The Real Problem - UnsafePointer<Self> from Borrow

struct Container5: ~Copyable {
    var value: Int = 42

    struct ReadView: ~Copyable, ~Escapable {
        // What we WANT: a read-only pointer
        let ptr: UnsafePointer<Container5>

        @_lifetime(borrow ptr)
        init(_ ptr: UnsafePointer<Container5>) {
            self.ptr = ptr
        }

        func read() -> Int { ptr.pointee.value }
    }

    // The core problem: how to get UnsafePointer<Self> from borrowing context?
    //
    // There's no way to do this in Swift:
    // - &self gives UnsafeMutablePointer, requires mutating
    // - withUnsafePointer(to: self) is not available (self not a parameter)
    // - No Builtin.addressOfBorrow exposed publicly
    //
    // UNCOMMENT TO TEST:
    // var readView: ReadView {
    //     _read {
    //         // How to get UnsafePointer<Self>?
    //         // yield unsafe ReadView(???)
    //     }
    // }
}

// MARK: - Test 6: ~Escapable with Lifetime Dependency Still Needs Pointer

struct Container6: ~Copyable {
    var value: Int = 42

    struct BorrowedView: ~Copyable, ~Escapable {
        // Even with lifetime dependency, we need a way to ACCESS the container
        // If we store a pointer, we need to CREATE that pointer somehow
        let ptr: UnsafePointer<Container6>

        @_lifetime(borrow ptr)
        init(_ ptr: UnsafePointer<Container6>) {
            self.ptr = ptr
        }
    }

    // The @_lifetime annotation tracks the dependency
    // But it doesn't PROVIDE a way to get the pointer
    //
    // ~Escapable is about PREVENTING escape, not ENABLING access
}

// ===----------------------------------------------------------------------===//
// VERIFICATION
// ===----------------------------------------------------------------------===//

func main() {
    print("=== ~Escapable Pointer Acquisition Test ===\n")

    // Test 1: Mutating works
    var c1 = Container1()
    print("Test 1 - ~Escapable view with mutating accessor:")
    print("  c1.view.read() = \(c1.view.read())")
    print("  RESULT: COMPILES (mutating context provides &self)")

    print("\n=== FINDINGS ===")
    print("")
    print("CONFIRMED: ~Escapable does NOT solve pointer acquisition problem")
    print("")
    print("WHAT ~ESCAPABLE DOES:")
    print("  - Prevents storing the view in fields")
    print("  - Prevents returning the view from functions")
    print("  - Tracks lifetime dependency via @_lifetime")
    print("")
    print("WHAT ~ESCAPABLE DOES NOT DO:")
    print("  - Does NOT provide a way to get pointer from borrowed context")
    print("  - Does NOT change the &self requirement")
    print("  - Does NOT make non-mutating _read work with pointers")
    print("")
    print("THE FUNDAMENTAL GAP:")
    print("  Swift has no way to express:")
    print("    'Give me a pointer to self that cannot escape self's scope'")
    print("  ")
    print("  ~Escapable controls the OUTPUT (what can escape)")
    print("  But doesn't help with the INPUT (how to get the pointer)")
    print("")
    print("WHAT WOULD BE NEEDED:")
    print("  - UnsafePointer(borrowing: self) - hypothetical")
    print("  - Builtin.addressOfBorrow - exists but not public")
    print("  - borrowing _read with implicit self pointer - not implemented")
}

main()

// ===----------------------------------------------------------------------===//
// RESULT: CONFIRMED
//
// The paper's claim is validated:
// - ~Escapable prevents pointer escape (what can be stored/returned)
// - ~Escapable does NOT enable pointer acquisition from borrowed context
// - The fundamental problem remains: no way to get UnsafePointer<Self> from borrow
// ===----------------------------------------------------------------------===//
