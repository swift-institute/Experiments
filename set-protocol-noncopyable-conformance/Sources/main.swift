// MARK: - Set.Protocol ~Copyable Conformance Validation
// Purpose: Determine the exact blocker for `where Element: ~Copyable` conformance
//          when protocol requires `func contains(_ element: borrowing Element) -> Bool`.
// Hypothesis: REVISED — The blocker is NOT closure capture. Even trivial stubs fail.
//             Testing whether it's: (a) the `borrowing` convention, (b) the explicit
//             `where Element: ~Copyable`, (c) implicit Copyable on generic witness, or
//             (d) a compiler limitation.
//
// Toolchain: Apple Swift 6.2.4 (swiftlang-6.2.4.1.4)
// Platform: macOS 26.0 (arm64)
//
// Result: CONFIRMED — Three findings:
//
//   F1: `where Element: ~Copyable` in conformance clause breaks witness matching.
//       "candidate would match if 'Element' conformed to 'Copyable'" — even for
//       trivial `{ false }` stubs. FIX: Use bare `extension T: P {}` instead.
//       The struct's `Element: ~Copyable` already propagates; the where clause is
//       redundant and triggers a compiler bug.
//
//   F2: Closures consume captured ~Copyable values — no borrowing closure capture.
//       `{ stored == element }` where element is `borrowing Element: ~Copyable`
//       fails: "'element' is borrowed and cannot be consumed". This means
//       hash-table lookup closures (`equals: { idx in buffer[idx] == element }`)
//       cannot be used for ~Copyable elements. Linear scan works.
//
//   F3: `hashValue` computed property (via `where Self: ~Copyable` extension) not
//       found on `T: HashProto & ~Copyable`. May be related to F1. Workaround:
//       call `hash(into:)` directly and compute hash manually.
//
//   All V1-V12 variants (excluding V10's explicit where clause and V11's closure
//   variant) compile and run correctly. V11 linear scan with isDisjoint defaults
//   produces correct results. Build Succeeded.
//
// Date: 2026-03-02

// ============================================================================
// MARK: - Infrastructure
// ============================================================================

protocol EqProto: ~Copyable {
    static func == (lhs: borrowing Self, rhs: borrowing Self) -> Bool
}

protocol HashProto: EqProto & ~Copyable {
    borrowing func hash(into hasher: inout Hasher)
}

// Conformance for Int so we can use it as an element
extension Int: EqProto {}
extension Int: HashProto {
    // Satisfied by stdlib Hashable.hash(into:)
}

// ============================================================================
// MARK: - Protocol Under Test
// ============================================================================

protocol SetProto: ~Copyable {
    associatedtype Element: HashProto & ~Copyable
    func contains(_ element: borrowing Element) -> Bool
    func forEach<E: Error>(_ body: (borrowing Element) throws(E) -> Void) throws(E)
}

// ============================================================================
// MARK: - V1: Baseline — Copyable conformance (known to work)
// ============================================================================

struct V1<Element: HashProto & ~Copyable>: ~Copyable {
    var _count: Int = 0
}

extension V1 where Element: Copyable {
    func contains(_ element: borrowing Element) -> Bool { false }
    func forEach<E: Error>(_ body: (borrowing Element) throws(E) -> Void) throws(E) {}
}

extension V1: SetProto where Element: Copyable {}

// ============================================================================
// MARK: - V2: Remove `where Element: ~Copyable` — use bare conformance
// Hypothesis: Maybe the explicit `~Copyable` in conformance clause causes issues
// ============================================================================

struct V2<Element: HashProto & ~Copyable>: ~Copyable {
    var _count: Int = 0
}

extension V2 {
    func contains(_ element: borrowing Element) -> Bool { false }
    func forEach<E: Error>(_ body: (borrowing Element) throws(E) -> Void) throws(E) {}
}

// Bare conformance — no where clause (Element is already ~Copyable from struct decl)
extension V2: SetProto {}

// ============================================================================
// MARK: - V3: Protocol with `consuming` instead of `borrowing`
// Hypothesis: Maybe `consuming` works where `borrowing` doesn't
// ============================================================================

protocol SetProtoConsuming: ~Copyable {
    associatedtype Element: HashProto & ~Copyable
    func contains(_ element: consuming Element) -> Bool
}

struct V3<Element: HashProto & ~Copyable>: ~Copyable {
    var _count: Int = 0
}

extension V3 {
    func contains(_ element: consuming Element) -> Bool { false }
}

extension V3: SetProtoConsuming {}

// ============================================================================
// MARK: - V4: Protocol without borrowing/consuming (requires Copyable implicitly?)
// Hypothesis: Omitting ownership annotation forces Copyable on the parameter
// ============================================================================

// Note: This should fail to compile because ~Copyable params must specify ownership
// But let's test to confirm.

// protocol SetProtoPlain: ~Copyable {
//     associatedtype Element: HashProto & ~Copyable
//     func contains(_ element: Element) -> Bool  // no ownership annotation
// }

// ============================================================================
// MARK: - V5: Simpler protocol — just one requirement, no forEach
// Hypothesis: Maybe the interaction of two requirements causes issues
// ============================================================================

protocol SimpleContains: ~Copyable {
    associatedtype Element: HashProto & ~Copyable
    func contains(_ element: borrowing Element) -> Bool
}

struct V5<Element: HashProto & ~Copyable>: ~Copyable {
    var _count: Int = 0
}

extension V5 {
    func contains(_ element: borrowing Element) -> Bool { false }
}

extension V5: SimpleContains {}

// ============================================================================
// MARK: - V6: Protocol with just forEach (no contains)
// Hypothesis: Does forEach alone work for ~Copyable conformance?
// ============================================================================

protocol SimpleForEach: ~Copyable {
    associatedtype Element: HashProto & ~Copyable
    func forEach<E: Error>(_ body: (borrowing Element) throws(E) -> Void) throws(E)
}

struct V6<Element: HashProto & ~Copyable>: ~Copyable {
    var _count: Int = 0
}

extension V6 {
    func forEach<E: Error>(_ body: (borrowing Element) throws(E) -> Void) throws(E) {}
}

extension V6: SimpleForEach {}

// ============================================================================
// MARK: - V7: Protocol with Element: EqProto only (drop HashProto)
// Hypothesis: Maybe HashProto constraint on associated type is the issue
// ============================================================================

protocol EqContains: ~Copyable {
    associatedtype Element: EqProto & ~Copyable
    func contains(_ element: borrowing Element) -> Bool
}

struct V7<Element: EqProto & ~Copyable>: ~Copyable {
    var _count: Int = 0
}

extension V7 {
    func contains(_ element: borrowing Element) -> Bool { false }
}

extension V7: EqContains {}

// ============================================================================
// MARK: - V8: No constraint on associated type at all
// Hypothesis: Is the issue the constraint on the associated type?
// ============================================================================

protocol BareContains: ~Copyable {
    associatedtype Element: ~Copyable
    func contains(_ element: borrowing Element) -> Bool
}

struct V8<Element: ~Copyable>: ~Copyable {
    var _count: Int = 0
}

extension V8 {
    func contains(_ element: borrowing Element) -> Bool { false }
}

extension V8: BareContains {}

// ============================================================================
// MARK: - V9: Equation.Protocol's own pattern — static method, Self is ~Copyable
// Hypothesis: Maybe the issue is specific to associated types, not Self
// ============================================================================

// Equation.Protocol works: `static func == (lhs: borrowing Self, rhs: borrowing Self) -> Bool`
// The difference is: Element is an associated type, Self is the conforming type.

protocol SelfBorrowing: ~Copyable {
    func probe(_ other: borrowing Self) -> Bool
}

struct V9<Element: ~Copyable>: ~Copyable {
    var _count: Int = 0
}

extension V9 {
    func probe(_ other: borrowing Self) -> Bool { false }
}

extension V9: SelfBorrowing {}

// ============================================================================
// MARK: - V10: Explicit `where Element: ~Copyable` (regression test)
// Hypothesis: The explicit `where Element: ~Copyable` in conformance clause
//             causes "would match if Element conformed to Copyable" — the bare
//             conformance in V2 (no where clause) works fine.
// ============================================================================

struct V10<Element: HashProto & ~Copyable>: ~Copyable {
    var _count: Int = 0
}

extension V10 {
    func contains(_ element: borrowing Element) -> Bool { false }
    func forEach<E: Error>(_ body: (borrowing Element) throws(E) -> Void) throws(E) {}
}

// FAILS: "candidate would match if 'Element' conformed to 'Copyable'"
// extension V10: SetProto where Element: ~Copyable {}

// FIX: Use bare conformance instead
extension V10: SetProto {}

// ============================================================================
// MARK: - V11: Closure capture of borrowed ~Copyable — REFUTED
// Hypothesis: Closure `{ ... == element }` works when element is borrowing ~Copyable
// Result: REFUTED — "'element' is borrowed and cannot be consumed"
//         Closures consume captured ~Copyable values. Borrowing captures aren't supported.
// ============================================================================

// (commented out — fails to compile)
// struct V11Fail<Element: HashProto & ~Copyable>: ~Copyable {
//     var _e0: Element?
// }
// extension V11Fail {
//     func contains(_ element: borrowing Element) -> Bool {
//         let probe = { // consumes element
//             if let stored = _e0 { return stored == element }
//             return false
//         }
//         return probe()
//     }
// }

// ============================================================================
// MARK: - V11: Linear scan without closures (the working alternative)
// Hypothesis: borrowing == comparison works directly (no closure capture needed)
// ============================================================================

struct V11<Element: HashProto & ~Copyable>: ~Copyable {
    var _e0: Element?
    var _e1: Element?
    var _count: Int = 0
}

extension V11 where Element: Copyable {
    init(_ a: Element, _ b: Element) {
        _e0 = a; _e1 = b; _count = 2
    }
}

extension V11 {
    func contains(_ element: borrowing Element) -> Bool {
        // Linear scan — no closures, borrowing == works directly
        if let e0 = _e0, e0 == element { return true }
        if let e1 = _e1, e1 == element { return true }
        return false
    }

    func forEach<E: Error>(_ body: (borrowing Element) throws(E) -> Void) throws(E) {
        if let e0 = _e0 { try body(e0) }
        if let e1 = _e1 { try body(e1) }
    }
}

extension V11: SetProto {}

// ============================================================================
// MARK: - V12: Defaults on ~Copyable conformers
// Hypothesis: Protocol defaults (isDisjoint etc.) work for ~Copyable conformers
// ============================================================================

extension SetProto where Self: ~Copyable {
    func isDisjoint<Other: SetProto & ~Copyable>(
        with other: borrowing Other
    ) -> Bool where Other.Element == Element {
        var disjoint = true
        forEach { element in
            if disjoint, other.contains(element) { disjoint = false }
        }
        return disjoint
    }
}

// ============================================================================
// MARK: - Execution
// ============================================================================

print("V1  (Copyable conformance):     compiled ✓")
print("V2  (bare conformance):         compiled ✓")
print("V3  (consuming contains):       compiled ✓")
print("V5  (just contains):            compiled ✓")
print("V6  (just forEach):             compiled ✓")
print("V7  (EqProto constraint):       compiled ✓")
print("V8  (no constraint):            compiled ✓")
print("V9  (borrowing Self):           compiled ✓")
print("V10 (bare conformance fix):     compiled ✓")
print("V11 (linear scan, no closure):  ?")
print("V12 (defaults on ~Copyable):    ?")

// Test V11 with Copyable elements
let s1 = V11<Int>(1, 2)
let s2 = V11<Int>(3, 4)
let s3 = V11<Int>(2, 5)
print("V11: contains(1)=\(s1.contains(1)), contains(3)=\(s1.contains(3))")
print("V11: isDisjoint(s1,s2)=\(s1.isDisjoint(with: s2)), isDisjoint(s1,s3)=\(s1.isDisjoint(with: s3))")

// Verify hash access on borrowing ~Copyable
// hashValue computed property via `where Self: ~Copyable` — doesn't resolve
// func testBorrowingHash<T: HashProto & ~Copyable>(_ value: borrowing T) -> Int {
//     value.hashValue  // ERROR: no member 'hashValue'
// }

// But hash(into:) directly works (it's a protocol requirement, not extension):
func testBorrowingHashDirect<T: HashProto & ~Copyable>(_ value: borrowing T) -> Int {
    var hasher = Hasher()
    value.hash(into: &hasher)
    return hasher.finalize()
}
print("hash(into:) on borrowing: \(testBorrowingHashDirect(42))")

print("\nDone.")
