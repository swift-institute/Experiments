// MARK: - Negative Tests (expected compiler errors)
// Each test is wrapped in #if false. Uncomment ONE AT A TIME to verify the error.
// The expected error is documented next to each test.

// ============================================================================
// NEG-V2A: Escapable struct containing ~Escapable field
// Expected: "stored property 'inner' of 'Escapable'-conforming struct has
//            non-Escapable type"
// Result: CONFIRMED (2026-02-28, Swift 6.2.4)
// ============================================================================
#if false
struct NegInnerView_2a: ~Escapable {
    let value: Int
    @_lifetime(immortal)
    init(_ value: Int) { self.value = value }
}

struct NegContainingEscapable_2a {
    let inner: NegInnerView_2a  // ERROR
}
#endif

// ============================================================================
// NEG-V4A: Passing lifetime-dependent ~Escapable value to closure
// Expected: "lifetime-dependent variable escapes its scope"
// Result: CONFIRMED (2026-02-28, Swift 6.2.4)
//
// KEY INSIGHT: The gap only manifests when the ~Escapable value has a REAL
// lifetime dependency (e.g., @_lifetime(borrow source)). Values with
// @_lifetime(immortal) CAN be passed to closures because they have no
// dependency to violate.
// ============================================================================
#if false
struct NegDependentView: ~Escapable {
    let count: Int

    @_lifetime(borrow source)
    init(borrowing source: [Int]) {
        self.count = source.count
    }
}

func negWithDependentView<T>(_ array: [Int], _ body: (NegDependentView) -> T) -> T {
    let view = NegDependentView(borrowing: array)
    return body(view)  // ERROR: lifetime-dependent variable escapes its scope
}
#endif

// ============================================================================
// NEG-V4A-IMMORTAL: Passing @_lifetime(immortal) ~Escapable value to closure
// Expected: COMPILES (no dependency to violate)
// Result: CONFIRMED (2026-02-28, Swift 6.2.4)
//
// This is a REFINEMENT of the original Edge Case 4 claim. The closure
// integration gap is specifically about lifetime-DEPENDENT values, not all
// ~Escapable values.
// ============================================================================
struct NegImmortalView: ~Escapable {
    let value: Int
    @_lifetime(immortal)
    init(_ value: Int) { self.value = value }
}

func negWithImmortalView<T>(_ body: (NegImmortalView) -> T) -> T {
    let view = NegImmortalView(42)
    return body(view)  // OK: immortal has no dependency to violate
}

let immortalResult = negWithImmortalView { $0.value }
// Used in main.swift's Edge Case 4 output

// ============================================================================
// NEG-V8: Creating Span in deinit
// Expected: "lifetime-dependent variable 's' escapes its scope"
// Result: CONFIRMED (2026-02-28, Swift 6.2.4)
// ============================================================================
#if false
struct NegOwnedStorage: ~Copyable {
    var data: [Int] = [1, 2, 3]

    deinit {
        let s = data.span  // ERROR: lifetime-dependent variable escapes its scope
        _ = s
    }
}
#endif

// ============================================================================
// NEG-V6: SE-0507 borrow accessor
// Expected: compile error (not yet available in Swift 6.2.4)
// ============================================================================
#if false
struct NegSpanProvider {
    let data: [Int]

    var span: Span<Int> {
        borrow {  // ERROR: 'borrow' accessor not yet supported
            data.span
        }
    }
}
#endif
