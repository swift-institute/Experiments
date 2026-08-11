// MARK: - Witness Property/Method Name Collision
//
// Purpose: Verify whether Swift tolerates a struct with both a stored closure
//   property and a method sharing the same base name but differing by
//   parameter labels. Answers the design question: does the @Witness macro's
//   underscore convention (storage `_read` + method `read(from:into:)`) exist
//   because Swift mechanically requires it, or is it cosmetic convention
//   that could be dropped?
//
// Hypothesis: A struct can have `let read: (Int) -> Int` (stored closure)
//   AND `func read(from x: Int) -> Int` (labeled method) simultaneously,
//   because their Swift names differ (`read` vs `read(from:)`). Inside the
//   method body, an unlabeled call `read(x)` resolves unambiguously to the
//   property-closure because the method requires `from:` at the call site.
//   Therefore the @Witness underscore convention is NOT mechanically required
//   for disambiguation — it is convention, not necessity — EXCEPT possibly
//   in edge cases (same-signature collisions, zero-arg collisions) which
//   are tested as separate variants.
//
// Toolchain: Swift 6.3 release
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
// Platform: macOS 26 (arm64)
// Date: 2026-04-17
//
// Results (2026-04-17):
//
//   V1 (different-label coexistence):
//       CONFIRMED. `let read: (Int) -> Int` + `func read(from x: Int) -> Int`
//       coexist in one struct. Both callable at consumer site.
//         v.read(5) = 6 (property-closure)
//         v.read(from: 5) = 105 (method)
//
//   V2 (method-body resolution — unlabeled call):
//       CONFIRMED. Inside `func read(from:)`, `read(x)` with one unlabeled
//       Int argument resolves to the stored closure (method would require
//       `from:`).
//         v.read(from: 3) = 30 (closure path: 3 * 10)
//
//   V3 (self.prefix yields property-closure):
//       CONFIRMED. `self.read` (no parens) yields the stored closure as a
//       value, assignable to a local.
//         v.read(from: 7) = 1007 (via self.read binding + call)
//
//   V4 (same-signature: property + unlabeled method):
//       UNEXPECTED — compiles. `let read: (Int) -> Int` and
//       `func read(_ x: Int) -> Int` DO NOT collide at declaration;
//       property wins at call site.
//         v.read(5) = 6 (property, method value 1005 unreachable via this
//         syntax). The method `read(_:)` is effectively shadowed; only
//         `self.read(...)` could disambiguate but `self.read` yields the
//         property closure first.
//       Diagnostic command: `swift build -Xswiftc -DTEST_V4`  — Build complete.
//
//   V5 (zero-arg collision):
//       REFUTED — as expected. `let now: () -> Int` + `func now() -> Int`
//       fails with:
//         error: invalid redeclaration of 'now()'
//       Diagnostic command: `swift build -Xswiftc -DTEST_V5`
//
//   V6 (@Witness macro with NON-underscored storage):
//       CONFIRMED. `@Witness struct V6NoUnderscore { let read: (_ from: Int,
//       _ into: Int) -> Int }` compiles AND the macro-generated labeled
//       method coexists with the stored closure.
//         v.read(from: 3, into: 4) = 7  (labeled method, macro-generated)
//         v.read(10, 20) = 30            (stored closure, unlabeled call)
//       After macro change (2026-04-17): non-underscored storage no longer
//       receives the deprecation attribute. Clean build, no warnings.
//
//   V7 (@Witness macro WITH underscored storage — backwards compat):
//       CONFIRMED. Underscored storage preserves the deprecation attribute
//       pointing to the stripped-name method:
//         warning: '_read' is deprecated: Use 'read(from:into:)' instead
//       Existing swift-io source code continues to work unchanged.
//
// Conclusion:
//   The underscore convention on @Witness storage is MECHANICALLY REQUIRED
//   only for ZERO-PARAMETER closures (V5). For LABELED-PARAMETER closures —
//   which is the common case in IO (read / write / close / ready all have
//   labels) — the convention is PURELY COSMETIC: both the stored closure
//   and a macro-generated labeled method coexist without collision (V1, V6).
//   The property wins on unlabeled call (V4); the labeled method wins when
//   its labels are used.
//
//   Design implication: @Witness could drop underscore requirement for
//   labeled-parameter closures entirely. Consumer call sites become
//   identical (same labels). For zero-parameter closures, the underscore
//   remains mechanically necessary OR consumers simply invoke the stored
//   closure directly (e.g., `clock.now()` where `now` is the stored
//   closure).

public import Witnesses

// ============================================================================
// MARK: - V1: Different-label property + method coexistence
// ============================================================================
//
// Hypothesis: Stored property `read` and method `read(from:)` coexist in one
//   struct. Both are callable at the consumer site without ambiguity because
//   their Swift names differ.

struct V1Coexist {
    let read: (Int) -> Int = { $0 + 1 }
    func read(from x: Int) -> Int { return x + 100 }
}

func testV1() {
    let v = V1Coexist()
    let propertyCall = v.read(5)           // invokes the stored closure
    let methodCall = v.read(from: 5)       // invokes the method
    print("V1: property call v.read(5) = \(propertyCall)  (expect 6)")
    print("V1: method   call v.read(from: 5) = \(methodCall)  (expect 105)")
    precondition(propertyCall == 6, "V1: property call failed")
    precondition(methodCall == 105, "V1: method call failed")
}

// ============================================================================
// MARK: - V2: Method-body unlabeled call resolves to property-closure
// ============================================================================
//
// Hypothesis: Inside `func read(from:)`, an unlabeled call `read(x)` resolves
//   to the property-closure. The method cannot match (requires `from:`).

struct V2Resolution {
    let read: (Int) -> Int = { $0 * 10 }
    func read(from x: Int) -> Int {
        // Unlabeled call — method requires `from:`, so this must be the closure.
        return read(x)
    }
}

func testV2() {
    let v = V2Resolution()
    let result = v.read(from: 3)
    print("V2: v.read(from: 3) = \(result)  (expect 30 if unlabeled call is closure)")
    precondition(result == 30, "V2: expected closure to be called, got \(result)")
}

// ============================================================================
// MARK: - V3: self. prefix yields the property-closure
// ============================================================================
//
// Hypothesis: `self.read` (no parens) yields the stored closure value; can be
//   assigned to a local and invoked separately.

struct V3SelfPrefix {
    let read: (Int) -> Int = { $0 + 1000 }
    func read(from x: Int) -> Int {
        let closure: (Int) -> Int = self.read
        return closure(x)
    }
}

func testV3() {
    let v = V3SelfPrefix()
    let result = v.read(from: 7)
    print("V3: v.read(from: 7) = \(result)  (expect 1007 via self.read binding)")
    precondition(result == 1007, "V3: expected 1007, got \(result)")
}

// ============================================================================
// MARK: - V4: Same-signature collision (expected REFUTED / compile error)
// ============================================================================
//
// Hypothesis: `let read: (Int) -> Int` + `func read(_ x: Int) -> Int` share
//   the Swift name `read(_:)` for call purposes. This is a genuine collision
//   and does not compile. Expected diagnostic: "invalid redeclaration of 'read'"
//   or "ambiguous use of 'read'".

#if TEST_V4
struct V4Collision {
    let read: (Int) -> Int = { $0 + 1 }     // property closure: +1
    func read(_ x: Int) -> Int { x + 1000 } // method: +1000
}

func testV4() {
    let v = V4Collision()
    let result = v.read(5)
    print("V4: v.read(5) = \(result) — property=6 (via closure), method=1005")
    // Which wins?
}
#endif

// ============================================================================
// MARK: - V5: Zero-arg property + zero-arg method collision (expected REFUTED)
// ============================================================================
//
// Hypothesis: `let now: () -> Int` + `func now() -> Int` — both have the same
//   call-site appearance `foo.now()`. Expected collision at declaration or
//   ambiguity at call site.

#if TEST_V5
struct V5ZeroArg {
    let now: () -> Int = { 42 }
    func now() -> Int { 99 }
}

func testV5() {
    let v = V5ZeroArg()
    let result = v.now()
    print("V5: v.now() = \(result) — property=42 (via closure), method=99")
}
#endif

// ============================================================================
// MARK: - V6: @Witness macro with NON-underscored storage
// ============================================================================
//
// Hypothesis: The @Witness macro synthesizes a labeled method `read(from:into:)`
//   from a stored closure named `read` (no underscore). If the macro tolerates
//   non-underscored storage, the underscore convention is purely cosmetic.
//   If the macro requires underscore storage to avoid collision in the
//   generated method, the convention IS mechanically required.
//
// Guarded with `#if TEST_V6` because the macro may reject non-underscored
// storage with a confusing diagnostic that would mask V1–V3 results.

#if TEST_V6

@Witness
struct V6NoUnderscore {
    let read: (_ from: Int, _ into: Int) -> Int
}

func testV6() {
    let v = V6NoUnderscore(read: { from, into in from + into })
    // Does the macro-generated `read(from:into:)` method exist and work?
    let methodResult = v.read(from: 3, into: 4)
    // Does the stored closure still callable unlabeled?
    let closureResult = v.read(10, 20)
    print("V6: method   call v.read(from: 3, into: 4) = \(methodResult)")
    print("V6: closure call v.read(10, 20) = \(closureResult)")
}

#endif

// ============================================================================
// MARK: - V7: @Witness macro WITH underscored storage — deprecation preserved
// ============================================================================
//
// Hypothesis: After the macro change (2026-04-17), underscored storage names
//   STILL receive the deprecation attribute pointing to the stripped-name
//   method. Backwards-compatible with existing swift-io source.

#if TEST_V7

@Witness
struct V7UnderscoreStillDeprecated {
    let _read: (_ from: Int, _ into: Int) -> Int
}

func testV7() {
    let v = V7UnderscoreStillDeprecated(read: { from, into in from + into })
    // Calling v._read(...) should emit a deprecation warning pointing to
    // v.read(from:into:).
    // The @Witness macro generates:  public func read(from:into:)
    let methodResult = v.read(from: 3, into: 4)
    print("V7: v.read(from: 3, into: 4) = \(methodResult)")
}

#endif

// ============================================================================
// MARK: - Runner
// ============================================================================

print("== Witness Property/Method Collision Experiment ==")
testV1()
testV2()
testV3()
print("V1–V3 CONFIRMED (assuming no precondition trap above).")

#if TEST_V4
testV4()
#endif

#if TEST_V5
testV5()
#endif

#if TEST_V6
testV6()
#endif

#if TEST_V7
testV7()
#endif
