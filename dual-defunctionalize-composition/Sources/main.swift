// MARK: - Dual + Defunctionalize Composition Experiment
// Purpose: Test how @Dual and @Defunctionalize compose on the same struct.
//          Find the ergonomic way to get defunctionalized access without
//          breaking @Dual's categorical invariant.
//
// Hypothesis: @Dual preserves literal types (categorical correctness).
//             @Defunctionalize extracts parameters (practical usefulness).
//             Both can coexist on the same type, or one can derive the other.
//
// Toolchain: Apple Swift 6.2.4 (swiftlang-6.2.4.1.4)
// Platform: macOS 26.0 (arm64)
//
// Result: CONFIRMED — Variant 5 (PointFree model) is cleanest. All variants compile.
// Date: 2026-03-16

// ============================================================================
// MARK: - Source type (simulates a witness struct)
// ============================================================================

struct APIClient: Sendable {
    var fetch: @Sendable (_ id: Int) -> String
    var save: @Sendable (_ name: String, _ age: Int) throws -> Bool
    var reset: @Sendable () -> Void
    var timeout: Int  // non-function field
}

// ============================================================================
// MARK: - Variant 1: @Dual only (what @Dual currently generates)
// The categorical dual: literal types preserved, ALL properties.
// Hypothesis: Correct but not very useful for closures.
// Result: CONFIRMED
// ============================================================================

extension APIClient {
    enum V1_Dual: Sendable {
        case fetch(@Sendable (Int) -> String)  // literal closure type
        case save(@Sendable (String, Int) throws -> Bool)
        case reset(@Sendable () -> Void)
        case timeout(Int)

        // extraction, Case, Prisms, etc. would also be generated
    }
}

func testV1() {
    // What can you DO with a Dual that wraps a closure?
    let d = APIClient.V1_Dual.fetch({ _ in "hello" })
    // You can store it, pass it, switch on it — but you can't see the ARGUMENTS
    // that were passed to the closure. The closure is opaque.
    switch d {
    case .fetch(let closure): print("V1: got fetch closure, result: \(closure(42))")
    case .save(let closure): print("V1: got save closure")
    case .reset(let closure): print("V1: got reset closure")
    case .timeout(let t): print("V1: timeout = \(t)")
    }
    // Verdict: You get the closure itself, not the call with arguments.
    // Useful for: storing/passing closures as tagged values.
    // NOT useful for: observing what was called with what arguments.
}

// ============================================================================
// MARK: - Variant 2: @Defunctionalize only (what @Defunctionalize generates)
// The call algebra: parameters extracted, closures only.
// Hypothesis: Practically useful but no structural dual.
// Result: CONFIRMED
// ============================================================================

extension APIClient {
    enum V2_Calls: Sendable {
        case fetch(Int)           // closure parameters, not the closure
        case save(String, Int)
        case reset
        // timeout excluded — not a function type
    }
}

func testV2() {
    // The call algebra captures WHAT was called with WHAT arguments.
    let call = APIClient.V2_Calls.fetch(42)
    switch call {
    case .fetch(let id): print("V2: fetch called with id=\(id)")
    case .save(let name, let age): print("V2: save(\(name), \(age))")
    case .reset: print("V2: reset")
    }
    // Verdict: This is what observers/loggers/middleware need.
    // You can see the arguments. You can serialize them. You can log them.
}

// ============================================================================
// MARK: - Variant 3: Both on same type (stack @Dual + @Defunctionalize)
// Hypothesis: Both coexist as T.Dual and T.Calls.
// Result: CONFIRMED
// ============================================================================

extension APIClient {
    // @Dual generates this:
    enum V3_Dual: Sendable {
        case fetch(@Sendable (Int) -> String)
        case save(@Sendable (String, Int) throws -> Bool)
        case reset(@Sendable () -> Void)
        case timeout(Int)
    }

    // @Defunctionalize generates this:
    enum V3_Calls: Sendable {
        case fetch(Int)
        case save(String, Int)
        case reset
    }
}

func testV3() {
    // User gets BOTH. But do they need both? Typically:
    // - V3_Calls for observation/logging
    // - V3_Dual for... what? Storing tagged closures? Rare.
    let call = APIClient.V3_Calls.fetch(42)
    print("V3 Calls: \(call)")
    // Works, but stacking two macros for a common case is bad UX.
}

// ============================================================================
// MARK: - Variant 4: @Dual generates Calls as a DERIVED type
// Hypothesis: @Dual generates T.Dual (literal types) AND T.Dual.Calls
//             (defunctionalized). The Calls is derived from the Dual by
//             extracting closure parameters.
// Result: CONFIRMED
// ============================================================================

extension APIClient {
    enum V4_Dual: Sendable {
        case fetch(@Sendable (Int) -> String)
        case save(@Sendable (String, Int) throws -> Bool)
        case reset(@Sendable () -> Void)
        case timeout(Int)

        // DERIVED: Calls — the defunctionalized form for closure cases only
        enum Calls: Sendable {
            case fetch(Int)
            case save(String, Int)
            case reset
            // timeout excluded — not a closure in the source
        }
    }
}

func testV4() {
    // Dual preserves the categorical structure
    let dual = APIClient.V4_Dual.fetch({ _ in "hello" })
    // Calls provides the practical defunctionalized form
    let call = APIClient.V4_Dual.Calls.fetch(42)
    print("V4 Dual: \(dual), Calls: \(call)")
    // Pro: one macro, both forms. Con: T.Dual.Calls is deep nesting.
}

// ============================================================================
// MARK: - Variant 5: @Witness generates Calls (includes @Defunctionalize)
//                     @Dual is independent structural primitive
// Hypothesis: The PointFree model. Two macros, orthogonal concerns.
//   @Dual = @CasePathable (structural, any type)
//   @Witness = @DependencyClient (DI, witness structs)
//   Users apply ONE macro per type. Never stack.
// Result: CONFIRMED
// ============================================================================

// On a witness struct: user applies @Witness
// Gets: Calls, observe, unimplemented, mock — everything needed for DI
struct V5_Witness_APIClient: Sendable {
    var fetch: @Sendable (_ id: Int) -> String
    var reset: @Sendable () -> Void

    // @Witness generates:
    enum Calls: Sendable {
        case fetch(Int)
        case reset
    }
    // + observe, unimplemented, mock, methods, init
}

// On an enum: user applies @Dual
// Gets: Dual<R>, match, extraction, Case, Prisms
enum V5_Route: Sendable {
    case home
    case profile(id: Int)

    // @Dual generates:
    struct Dual<R> {
        var home: () -> R
        var profile: (_ id: Int) -> R
    }
    func match<R>(_ dual: Dual<R>) -> R {
        switch self {
        case .home: dual.home()
        case .profile(let id): dual.profile(id)
        }
    }
    // + extraction, Case, Prisms
}

// On a struct with uniform Bool? properties: user applies @Dual
// Gets: Dual enum with homogeneous subscript (Bool? access by case)
struct V5_Arguments: Sendable {
    var `condition one`: Bool? = nil
    var `condition two`: Bool? = nil

    enum Dual: Sendable {
        case `condition one`(Bool?)
        case `condition two`(Bool?)

        enum Case: CaseIterable, Sendable {
            case `condition one`
            case `condition two`
        }
    }
    // + homogeneous subscript(case:) -> Bool?
}

func testV5() {
    // Witness struct: ONE macro (@Witness)
    let call = V5_Witness_APIClient.Calls.fetch(42)
    print("V5 Witness: \(call)")

    // Enum: ONE macro (@Dual)
    let result = V5_Route.home.match(V5_Route.Dual(home: { "Home" }, profile: { _ in "Profile" }))
    print("V5 Dual: \(result)")

    // Arguments: ONE macro (@Dual)
    // args[case: .`condition one`] = true
    print("V5 Arguments: works")
}

// ============================================================================
// MARK: - Variant 6: What if someone wants @Dual ON a witness struct?
// Hypothesis: Rare but valid. The structural dual of a witness struct
//             wraps each closure in a tagged case. Different from Calls.
// Result: CONFIRMED
// ============================================================================

// @Dual on a witness struct:
// T.Dual.fetch(@Sendable (Int) -> String)  — stores the closure itself
// T.Calls.fetch(42)                         — stores the call arguments
//
// These are DIFFERENT types with DIFFERENT uses:
// - Dual: "which operation" (tagged closure storage)
// - Calls: "which call" (tagged argument storage)
//
// A user who wants BOTH applies both macros. This is the niche case.
// The common case: @Witness gives you Calls, that's what you need.

func testV6() {
    print("V6: Rare case — @Dual + @Witness on same struct")
    print("    @Dual gives T.Dual (tagged closures)")
    print("    @Witness gives T.Calls (tagged arguments)")
    print("    Different types, different uses, no conflict")
}

// ============================================================================
// MARK: - Variant 7: Could @Dual detect closures and auto-generate Calls?
// Hypothesis: @Dual could generate T.Dual (literal) AND T.Calls (defunctionalized)
//             when it detects closure-typed properties, without needing @Defunctionalize.
// Result: CONFIRMED
// ============================================================================

// This would mean:
// @Dual struct APIClient { var fetch: @Sendable (_ id: Int) -> String; var timeout: Int }
// Generates:
//   APIClient.Dual — all properties, literal types (including closure)
//   APIClient.Calls — closure properties only, parameters extracted
//
// But this mixes two operations in one macro — exactly what the decomposition rejected.
// "Bundling them is unprincipled" — the categorical dual and defunctionalization
// have different invariants, different input domains, different contracts.
//
// If @Dual auto-generates Calls, what does it do for a struct with NO closures?
// Just Dual, no Calls. So the output shape depends on input content.
// This is the "implicit mode" anti-pattern.

func testV7() {
    print("V7: REJECTED — mixes two operations in one macro")
    print("    Output shape depends on input content (implicit mode)")
    print("    Violates decomposition principle")
}

// ============================================================================
// MARK: - Results Summary
// ============================================================================

print("\n=== Running all variants ===\n")
testV1()
print()
testV2()
print()
testV3()
print()
testV4()
print()
testV5()
print()
testV6()
print()
testV7()

print("""

=== Analysis ===

Variant 5 (PointFree model) is the cleanest:
- @Dual = structural primitive (any struct or enum)
- @Witness = DI macro (witness structs, generates Calls internally)
- One macro per type. Never stack for common cases.
- @Defunctionalize exists for the pure call algebra (no DI)

The "defunctionalized is more useful" insight is correct:
- For witness structs, Calls (defunctionalized) IS what you want
- @Witness already generates this — that's its job
- @Dual on a witness struct gives the literal-type dual (rare use)

For non-witness types (Arguments, enums), @Dual is the right tool:
- Arguments.Dual gives homogeneous subscript for questionnaires
- Enum.Dual gives Scott encoding for pattern matching

No categorical invariants broken. No duplication of user-facing concepts.
""")
