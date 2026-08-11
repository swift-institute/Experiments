// MARK: - Tag-Preserving Protocol Abstraction Experiment
// Purpose: Test whether cross-type operators (Ordinal + Cardinal, Vector < Cardinal)
//          can be unified across bare and tagged forms while preserving the same-tag
//          constraint that prevents cross-domain mixing.
//
// Problem: The current protocol abstraction (Cardinal.Protocol, Ordinal.Protocol)
//          erases the phantom tag. A function `<O: Ordinal.Protocol, C: Cardinal.Protocol>`
//          cannot enforce that O and C share the same Tag. This means:
//          - Tagged<Foo, Ordinal> + Tagged<Bar, Cardinal> would compile (WRONG)
//          - 14 of 31 operator pairs cannot be unified without this constraint
//
// Hypothesis: Adding an associated `Domain` type to each protocol can recover the
//             same-tag guarantee while preserving the single-definition benefit.
//
// Toolchain: Apple Swift 6.2.3
// Platform: macOS 26 (arm64)
//
// Result: CONFIRMED — All variants pass. The `associatedtype Domain` approach
//         recovers full same-tag enforcement for cross-type operators.
//
//   V1a (same-type ops):              CONFIRMED — Domain ignored, works as before
//   V1b (cross-type + tag enforce):   CONFIRMED — bare (Never==Never) and tagged (Foo==Foo) both work
//   V1c (cross-type comparisons):     CONFIRMED — Vector<Cardinal, Cardinal<Vector, Ordinal<Cardinal all work
//   V1d (companion types O-O→V):      CONFIRMED — associated CompanionVector maps to correct type
//   V2  (primary assoc type syntax):  CONFIRMED — `where O.D == C.D` works
//   V3  (Never==Never for bare):      CONFIRMED — bare types interoperate via Never==Never
//   V4  (cross-domain rejection):     CONFIRMED — Tagged<Foo>+Tagged<Bar> produces compile error:
//         "requires the types 'NegFoo' and 'NegBar' be equivalent"
//   V5  (compound assignment):        CONFIRMED — += and -= with tag enforcement
//   V6  (companion types):            CONFIRMED — Ordinal-Ordinal→Vector returns Tagged<Tag,Vector> for tagged
//   V7  (full comparison suite):      CONFIRMED — all 8 Vector↔Cardinal comparisons unified
//
//   This brings the unifiable count from 17/31 to 31/31 (full unification).
//
// Date: 2026-02-04

// =============================================================================
// MARK: - Minimal Type Reproductions
// =============================================================================

struct Cardinal: Hashable, Sendable {
    let rawValue: UInt
    init(_ value: UInt) { self.rawValue = value }
}

struct Ordinal: Hashable, Sendable {
    let rawValue: UInt
    init(_ value: UInt) { self.rawValue = value }
}

struct Vector: Hashable, Sendable {
    let rawValue: Int
    init(_ value: Int) { self.rawValue = value }
}

struct Tagged<Tag, RawValue> {
    let rawValue: RawValue
    init(__unchecked: Void = (), _ rawValue: RawValue) { self.rawValue = rawValue }
}
extension Tagged: Equatable where RawValue: Equatable {}
extension Tagged: Hashable where RawValue: Hashable {}
extension Tagged: Sendable where RawValue: Sendable {}

// =============================================================================
// MARK: - Variant 1: Associated Domain type — same-tag enforcement
// =============================================================================

// Hypothesis: Add `associatedtype Domain` to each protocol. Bare types use
// `Domain = Never` (or a sentinel). Tagged types use `Domain = Tag`.
// Cross-type operators constrain `O.Domain == C.Domain`.
//
// Result: CONFIRMED — Domain = Never for bare, Domain = Tag for tagged. where O.Domain == C.Domain works.

extension Cardinal {
    protocol `Protocol` {
        associatedtype Domain
        var cardinal: Cardinal { get }
        init(_ cardinal: Cardinal)
    }
}

extension Ordinal {
    protocol `Protocol` {
        associatedtype Domain
        var ordinal: Ordinal { get }
        init(_ ordinal: Ordinal)
    }
}

extension Vector {
    protocol `Protocol` {
        associatedtype Domain
        var vector: Vector { get }
        init(_ vector: Vector)
    }
}

// --- Bare type conformances (Domain = Never) ---

extension Cardinal: Cardinal.`Protocol` {
    typealias Domain = Never
    var cardinal: Cardinal { self }
    init(_ cardinal: Cardinal) { self = cardinal }
}

extension Ordinal: Ordinal.`Protocol` {
    typealias Domain = Never
    var ordinal: Ordinal { self }
    init(_ ordinal: Ordinal) { self = ordinal }
}

extension Vector: Vector.`Protocol` {
    typealias Domain = Never
    var vector: Vector { self }
    init(_ vector: Vector) { self = vector }
}

// --- Tagged conformances (Domain = Tag) ---

extension Tagged: Cardinal.`Protocol` where RawValue == Cardinal {
    typealias Domain = Tag
    var cardinal: Cardinal { rawValue }
    init(_ cardinal: Cardinal) { self.init(__unchecked: (), cardinal) }
}

extension Tagged: Ordinal.`Protocol` where RawValue == Ordinal {
    typealias Domain = Tag
    var ordinal: Ordinal { rawValue }
    init(_ ordinal: Ordinal) { self.init(__unchecked: (), ordinal) }
}

extension Tagged: Vector.`Protocol` where RawValue == Vector {
    typealias Domain = Tag
    var vector: Vector { rawValue }
    init(_ vector: Vector) { self.init(__unchecked: (), vector) }
}

// =============================================================================
// MARK: - V1a: Same-type operators (no cross-type, baseline)
// =============================================================================

// These already work with current protocol pattern. Domain is ignored.
// Result: CONFIRMED

func + <C: Cardinal.`Protocol`>(lhs: C, rhs: C) -> C {
    C(Cardinal(lhs.cardinal.rawValue + rhs.cardinal.rawValue))
}

func + <V: Vector.`Protocol`>(lhs: V, rhs: V) -> V {
    V(Vector(lhs.vector.rawValue + rhs.vector.rawValue))
}

func - <V: Vector.`Protocol`>(lhs: V, rhs: V) -> V {
    V(Vector(lhs.vector.rawValue - rhs.vector.rawValue))
}

// =============================================================================
// MARK: - V1b: Cross-type operators WITH same-tag enforcement
// =============================================================================

// Hypothesis: `where O.Domain == C.Domain` enforces that bare + bare works
// (Never == Never) and tagged + tagged works (Foo == Foo), but
// tagged + bare FAILS (Foo != Never). This is the desired behavior.
//
// Result: CONFIRMED — bare+bare (Never==Never), tagged+tagged (Foo==Foo), cross-domain rejected

// Ordinal + Cardinal → Ordinal (advance by count)
func + <O: Ordinal.`Protocol`, C: Cardinal.`Protocol`>(
    lhs: O, rhs: C
) -> O where O.Domain == C.Domain {
    O(Ordinal(lhs.ordinal.rawValue + rhs.cardinal.rawValue))
}

// Ordinal - Cardinal → Ordinal (retreat by count)
func - <O: Ordinal.`Protocol`, C: Cardinal.`Protocol`>(
    lhs: O, rhs: C
) -> O where O.Domain == C.Domain {
    O(Ordinal(lhs.ordinal.rawValue - rhs.cardinal.rawValue))
}

// Ordinal + Vector → Ordinal (affine translation)
func + <O: Ordinal.`Protocol`, V: Vector.`Protocol`>(
    lhs: O, rhs: V
) -> O where O.Domain == V.Domain {
    O(Ordinal(UInt(Int(lhs.ordinal.rawValue) + rhs.vector.rawValue)))
}

// Ordinal - Vector → Ordinal (affine retreat)
func - <O: Ordinal.`Protocol`, V: Vector.`Protocol`>(
    lhs: O, rhs: V
) -> O where O.Domain == V.Domain {
    O(Ordinal(UInt(Int(lhs.ordinal.rawValue) - rhs.vector.rawValue)))
}

// =============================================================================
// MARK: - V1c: Cross-type comparisons WITH same-tag enforcement
// =============================================================================

// Vector < Cardinal (bounds checking: is offset within count?)
// Result: CONFIRMED — all 8 comparisons + 2 ordinal-cardinal comparisons unified

func < <V: Vector.`Protocol`, C: Cardinal.`Protocol`>(
    lhs: V, rhs: C
) -> Bool where V.Domain == C.Domain {
    lhs.vector.rawValue < Int(rhs.cardinal.rawValue)
}

func <= <V: Vector.`Protocol`, C: Cardinal.`Protocol`>(
    lhs: V, rhs: C
) -> Bool where V.Domain == C.Domain {
    lhs.vector.rawValue <= Int(rhs.cardinal.rawValue)
}

func > <V: Vector.`Protocol`, C: Cardinal.`Protocol`>(
    lhs: V, rhs: C
) -> Bool where V.Domain == C.Domain {
    lhs.vector.rawValue > Int(rhs.cardinal.rawValue)
}

func >= <V: Vector.`Protocol`, C: Cardinal.`Protocol`>(
    lhs: V, rhs: C
) -> Bool where V.Domain == C.Domain {
    lhs.vector.rawValue >= Int(rhs.cardinal.rawValue)
}

// Reverse: Cardinal vs Vector
func < <C: Cardinal.`Protocol`, V: Vector.`Protocol`>(
    lhs: C, rhs: V
) -> Bool where C.Domain == V.Domain {
    Int(lhs.cardinal.rawValue) < rhs.vector.rawValue
}

func <= <C: Cardinal.`Protocol`, V: Vector.`Protocol`>(
    lhs: C, rhs: V
) -> Bool where C.Domain == V.Domain {
    Int(lhs.cardinal.rawValue) <= rhs.vector.rawValue
}

func > <C: Cardinal.`Protocol`, V: Vector.`Protocol`>(
    lhs: C, rhs: V
) -> Bool where C.Domain == V.Domain {
    Int(lhs.cardinal.rawValue) > rhs.vector.rawValue
}

func >= <C: Cardinal.`Protocol`, V: Vector.`Protocol`>(
    lhs: C, rhs: V
) -> Bool where C.Domain == V.Domain {
    Int(lhs.cardinal.rawValue) >= rhs.vector.rawValue
}

// Ordinal < Cardinal (and reverse)
func < <O: Ordinal.`Protocol`, C: Cardinal.`Protocol`>(
    lhs: O, rhs: C
) -> Bool where O.Domain == C.Domain {
    lhs.ordinal.rawValue < rhs.cardinal.rawValue
}

func < <C: Cardinal.`Protocol`, O: Ordinal.`Protocol`>(
    lhs: C, rhs: O
) -> Bool where C.Domain == O.Domain {
    lhs.cardinal.rawValue < rhs.ordinal.rawValue
}

// =============================================================================
// MARK: - V1d: Cross-type with DIFFERENT return type (Point - Point → Vector)
// =============================================================================

// Hypothesis: When Ordinal - Ordinal → Vector, the tagged version returns
// Tagged<Tag, Vector>. Can we express this via an associated VectorType?
//
// Result: CONFIRMED — CompanionVector maps Ordinal→Vector, Tagged<T,Ordinal>→Tagged<T,Vector>

// Approach: Add an associated type that maps to the "companion" type in the same domain.

protocol OrdinalWithCompanions {
    associatedtype Domain
    associatedtype CompanionVector: Vector.`Protocol`
    var ordinal: Ordinal { get }
    init(_ ordinal: Ordinal)
}

extension Ordinal: OrdinalWithCompanions {
    typealias CompanionVector = Vector
}

extension Tagged: OrdinalWithCompanions where RawValue == Ordinal {
    typealias CompanionVector = Tagged<Tag, Vector>
}

// Ordinal - Ordinal → Vector (companion type)
func - <O: OrdinalWithCompanions>(lhs: O, rhs: O) -> O.CompanionVector {
    O.CompanionVector(Vector(Int(lhs.ordinal.rawValue) - Int(rhs.ordinal.rawValue)))
}

// =============================================================================
// MARK: - V2: Alternative — Domain as a generic parameter on the protocol
// =============================================================================

// Hypothesis: Instead of associated type, use the protocol's primary associated type.
// This gives `Cardinal.Protocol<Never>` vs `Cardinal.Protocol<Tag>`.
// But we already know protocols can't nest in generic contexts...
// Actually Cardinal is NOT generic, so Cardinal.Protocol CAN have primary assoc types.
//
// Result: CONFIRMED — `where O.D == C.D` works identically to `where O.Domain == C.Domain`

// Can't redefine Cardinal.Protocol, so use a different name for this variant.
protocol CardinalP<D> {
    associatedtype D
    var cardinal: Cardinal { get }
    init(_ cardinal: Cardinal)
}

protocol OrdinalP<D> {
    associatedtype D
    var ordinal: Ordinal { get }
    init(_ ordinal: Ordinal)
}

extension Cardinal: CardinalP {
    typealias D = Never
}

extension Ordinal: OrdinalP {
    typealias D = Never
}

extension Tagged: CardinalP where RawValue == Cardinal {
    typealias D = Tag
}

extension Tagged: OrdinalP where RawValue == Ordinal {
    typealias D = Tag
}

// Cross-type with primary associated type syntax:
func advanceP<O: OrdinalP, C: CardinalP>(_ pos: O, by count: C) -> O where O.D == C.D {
    O(Ordinal(pos.ordinal.rawValue + count.cardinal.rawValue))
}

// =============================================================================
// MARK: - V3: Does Never == Never for bare types actually work?
// =============================================================================

// Hypothesis: When both Domain types are Never, the `where O.Domain == C.Domain`
// constraint resolves to `Never == Never` which is trivially true.
// This should allow bare Ordinal + bare Cardinal seamlessly.
//
// Result: CONFIRMED — Never == Never resolves trivially, bare cross-type ops work

func testBareNeverEquality() {
    let o = Ordinal(10)
    let c = Cardinal(3)
    let result = o + c  // Ordinal.Domain (Never) == Cardinal.Domain (Never)
    print("V3 bare:    Ordinal(10) + Cardinal(3) = Ordinal(\(result.ordinal.rawValue))")
}

// =============================================================================
// MARK: - V4: Negative test — cross-domain SHOULD fail
// =============================================================================

// Hypothesis: Tagged<Foo, Ordinal> + Tagged<Bar, Cardinal> should NOT compile
// because Foo != Bar. We can't test this at runtime (it's a compile error),
// but we document that uncommenting the line below produces the expected error.
//
// Result: CONFIRMED — compile error: "requires the types 'NegFoo' and 'NegBar' be equivalent"

enum Foo {}
enum Bar {}

func testCrossDomainRejection() {
    // These SHOULD compile:
    let taggedO = Tagged<Foo, Ordinal>(__unchecked: (), Ordinal(10))
    let taggedC = Tagged<Foo, Cardinal>(__unchecked: (), Cardinal(3))
    let result = taggedO + taggedC  // Foo == Foo ✓
    print("V4 same-tag: Tagged<Foo, Ordinal>(10) + Tagged<Foo, Cardinal>(3) = Tagged(\(result.ordinal.rawValue))")

    // This SHOULD NOT compile (uncomment to verify):
    // let badC = Tagged<Bar, Cardinal>(__unchecked: (), Cardinal(3))
    // let bad = taggedO + badC  // ERROR: Foo != Bar
    print("V4 cross-tag: (commented out — would be compile error, Foo != Bar)")
}

// =============================================================================
// MARK: - V5: Compound assignment with tag enforcement
// =============================================================================

// Result: CONFIRMED — compound assignment with tag enforcement works

func += <O: Ordinal.`Protocol`, C: Cardinal.`Protocol`>(
    lhs: inout O, rhs: C
) where O.Domain == C.Domain {
    lhs = lhs + rhs
}

func -= <O: Ordinal.`Protocol`, C: Cardinal.`Protocol`>(
    lhs: inout O, rhs: C
) where O.Domain == C.Domain {
    lhs = lhs - rhs
}

func testCompoundAssignment() {
    var o = Ordinal(10)
    o += Cardinal(5)
    print("V5 bare +=:  Ordinal(10) += Cardinal(5) = Ordinal(\(o.ordinal.rawValue))")

    var to = Tagged<Foo, Ordinal>(__unchecked: (), Ordinal(10))
    let tc = Tagged<Foo, Cardinal>(__unchecked: (), Cardinal(5))
    to += tc
    print("V5 tagged +=: Tagged<Foo>(10) += Tagged<Foo>(5) = Tagged(\(to.ordinal.rawValue))")
}

// =============================================================================
// MARK: - V6: Companion types for Ordinal - Ordinal → Vector
// =============================================================================

// Result: CONFIRMED — bare→Vector, tagged→Tagged<Tag,Vector>

func testCompanionType() {
    // Bare: Ordinal - Ordinal → Vector
    let o1 = Ordinal(10)
    let o2 = Ordinal(3)
    let v: Vector = o1 - o2
    print("V6 bare:    Ordinal(10) - Ordinal(3) = Vector(\(v.vector.rawValue))")

    // Tagged: Tagged<Foo, Ordinal> - Tagged<Foo, Ordinal> → Tagged<Foo, Vector>
    let to1 = Tagged<Foo, Ordinal>(__unchecked: (), Ordinal(10))
    let to2 = Tagged<Foo, Ordinal>(__unchecked: (), Ordinal(3))
    let tv: Tagged<Foo, Vector> = to1 - to2
    print("V6 tagged:  Tagged(10) - Tagged(3) = Tagged(Vector(\(tv.vector.rawValue)))")
}

// =============================================================================
// MARK: - V7: Full unification count — how many of the 14 "non-unifiable"
//             operators can now be unified?
// =============================================================================

// The 14 previously non-unifiable operators:
//   4x Ordinal ± Cardinal (with tag enforcement)     → V1b covers these
//   8x Vector ↔ Cardinal comparisons (with tag)      → V1c covers these
//   2x Ordinal ↔ Cardinal comparisons (with tag)     → V1c covers these
//
// Plus the Point - Point → Vector case:              → V1d covers this
//
// Result: CONFIRMED — all 14 previously non-unifiable operators now unified
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES

func testVectorCardinalComparison() {
    // Bare
    let v = Vector(3)
    let c = Cardinal(5)
    print("V7 bare:    Vector(3) < Cardinal(5) = \(v < c)")

    // Tagged (same tag)
    let tv = Tagged<Foo, Vector>(__unchecked: (), Vector(3))
    let tc = Tagged<Foo, Cardinal>(__unchecked: (), Cardinal(5))
    print("V7 tagged:  Tagged<Foo>(3) < Tagged<Foo>(5) = \(tv < tc)")

    // Reverse direction
    print("V7 reverse: Cardinal(5) > Vector(3) = \(c > v)")
    print("V7 reverse: Tagged<Foo>(5) > Tagged<Foo>(3) = \(tc > tv)")
}

// =============================================================================
// MARK: - Execution
// =============================================================================

func main() {
    // V1a: Same-type ops
    let c = Cardinal(5)
    let tc = Tagged<Foo, Cardinal>(__unchecked: (), Cardinal(5))
    let sum = c + Cardinal(3)
    let tsum = tc + Tagged<Foo, Cardinal>(__unchecked: (), Cardinal(3))
    print("V1a same-type: Cardinal \(sum.cardinal.rawValue), Tagged \(tsum.cardinal.rawValue)")

    // V1b: Cross-type with tag enforcement
    let o = Ordinal(10)
    let advance_bare = o + Cardinal(5)
    print("V1b cross-type: Ordinal(10) + Cardinal(5) = Ordinal(\(advance_bare.ordinal.rawValue))")

    let to = Tagged<Foo, Ordinal>(__unchecked: (), Ordinal(10))
    let advance_tagged = to + Tagged<Foo, Cardinal>(__unchecked: (), Cardinal(5))
    print("V1b tagged:     Tagged(10) + Tagged(5) = Tagged(\(advance_tagged.ordinal.rawValue))")

    // V1c: Cross-type comparisons
    print("V1c compare:    Vector(3) < Cardinal(5) = \(Vector(3) < Cardinal(5))")

    // V2: Primary associated type
    let r2 = advanceP(o, by: Cardinal(5))
    print("V2 primary:     advanceP(10, 5) = Ordinal(\(r2.ordinal.rawValue))")
    let r2t = advanceP(to, by: Tagged<Foo, Cardinal>(__unchecked: (), Cardinal(5)))
    print("V2 tagged:      advanceP(10, 5) = Tagged(\(r2t.ordinal.rawValue))")

    // V3: Never == Never
    testBareNeverEquality()

    // V4: Cross-domain rejection
    testCrossDomainRejection()

    // V5: Compound assignment
    testCompoundAssignment()

    // V6: Companion types
    testCompanionType()

    // V7: Full count
    testVectorCardinalComparison()

    print("\nAll variants executed successfully.")
}

main()
