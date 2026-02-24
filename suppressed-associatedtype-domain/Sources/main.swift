// MARK: - Suppressed Associated Type Domain Experiment
// Purpose: Re-test the Phase 2 blocker from noncopyable-associatedtype-domain
//          (2026-02-04) WITH the SuppressedAssociatedTypes feature flag.
//          The original experiment REFUTED `associatedtype Domain: ~Copyable`
//          but did NOT enable SuppressedAssociatedTypes.
//          The suppressed-associated-types experiment (2026-02-12) confirmed
//          `associatedtype Element: ~Copyable` compiles with the flag.
//          This experiment tests whether the same flag unblocks Domain.
//
// Toolchain: Apple Swift 6.2.3 (swiftlang-6.2.3.3.21) / Xcode 26 beta
// Platform: macOS 26.0 (arm64)
// Feature flag: SuppressedAssociatedTypes
//
// Result: ALL CONFIRMED — Phase 2 Domain unification is unblocked.
//   V1: CONFIRMED — associatedtype Domain: ~Copyable compiles
//   V2: CONFIRMED — Tagged wrapper conforms with Domain = Tag
//   V3: CONFIRMED — cross-type operators with Domain constraint work
//   V4: CONFIRMED — cross-domain rejection (Foo≠Bar, Never≠Foo)
//   V5: CONFIRMED — full Phase 2 (Ordinal + Cardinal + Vector + Count + comparisons)
//   V6: CONFIRMED — ~Copyable tag works as Domain witness
//
// Date: 2026-02-13

// ============================================================================
// MARK: - Variant 1: associatedtype Domain: ~Copyable compiles
// Hypothesis: With SuppressedAssociatedTypes, `associatedtype Domain: ~Copyable`
//             compiles (previously REFUTED without the flag).
// ============================================================================

protocol V1_Protocol: ~Copyable {
    associatedtype Domain: ~Copyable
    var value: Int { get }
}

struct V1_Bare: V1_Protocol {
    typealias Domain = Never
    var value: Int
}

struct V1_Tagged<Tag: ~Copyable>: V1_Protocol {
    typealias Domain = Tag
    var value: Int
}

enum V1_Tag {}
let v1a = V1_Bare(value: 1)
let v1b = V1_Tagged<V1_Tag>(value: 2)
print("V1 bare: \(v1a.value), tagged: \(v1b.value)")
print("V1: CONFIRMED — associatedtype Domain: ~Copyable compiles")

// ============================================================================
// MARK: - Variant 2: Tagged<Tag: ~Copyable, RawValue> conformance with Domain = Tag
// Hypothesis: A generic wrapper with `Tag: ~Copyable` can conform to a protocol
//             with `associatedtype Domain: ~Copyable` using `typealias Domain = Tag`.
// ============================================================================

struct V2_Wrapper<Tag: ~Copyable, RawValue> {
    var rawValue: RawValue
}

protocol V2_CardinalProto: ~Copyable {
    associatedtype Domain: ~Copyable
    var cardinal: Int { get }
    init(_ cardinal: Int)
}

struct V2_Cardinal: V2_CardinalProto {
    typealias Domain = Never
    var cardinal: Int
    init(_ cardinal: Int) { self.cardinal = cardinal }
}

extension V2_Wrapper: V2_CardinalProto where RawValue == Int, Tag: ~Copyable {
    typealias Domain = Tag
    var cardinal: Int { rawValue }
    init(_ cardinal: Int) { self.rawValue = cardinal }
}

func v2_double<C: V2_CardinalProto>(_ c: C) -> C {
    C(c.cardinal * 2)
}

let v2a = v2_double(V2_Cardinal(21))
let v2b = v2_double(V2_Wrapper<V1_Tag, Int>(rawValue: 21))
print("V2 bare: \(v2a.cardinal), tagged: \(v2b.cardinal)")
print("V2: CONFIRMED — Tagged wrapper conforms with Domain = Tag")

// ============================================================================
// MARK: - Variant 3: Cross-type operator with where O.Domain == C.Domain
// Hypothesis: Free functions with `where L.Domain == R.Domain` correctly
//             accept bare×bare and tagged×tagged (same tag).
// ============================================================================

protocol V3_OrdinalProto: ~Copyable {
    associatedtype Domain: ~Copyable
    var position: Int { get }
    init(position: Int)
}

protocol V3_CardinalProto: ~Copyable {
    associatedtype Domain: ~Copyable
    var count: Int { get }
}

struct V3_Ordinal: V3_OrdinalProto {
    typealias Domain = Never
    var position: Int
    init(position: Int) { self.position = position }
}

struct V3_Cardinal: V3_CardinalProto {
    typealias Domain = Never
    var count: Int
}

struct V3_TaggedOrd<Tag: ~Copyable>: V3_OrdinalProto {
    typealias Domain = Tag
    var position: Int
    init(position: Int) { self.position = position }
}

struct V3_TaggedCard<Tag: ~Copyable>: V3_CardinalProto {
    typealias Domain = Tag
    var count: Int
}

func + <O: V3_OrdinalProto, C: V3_CardinalProto>(
    lhs: O, rhs: C
) -> O where O.Domain == C.Domain {
    O(position: lhs.position + rhs.count)
}

// Bare + Bare: Never == Never
let v3a = V3_Ordinal(position: 5) + V3_Cardinal(count: 3)
print("V3 bare+bare: \(v3a.position)")

// Tagged + Tagged (same tag)
let v3b = V3_TaggedOrd<V1_Tag>(position: 10) + V3_TaggedCard<V1_Tag>(count: 7)
print("V3 tagged+tagged (same): \(v3b.position)")

print("V3: CONFIRMED — cross-type with Domain constraint works")

// ============================================================================
// MARK: - Variant 4: Cross-domain rejection
// Hypothesis: Tagged + Tagged with DIFFERENT tags fails to compile.
//             Uncomment to verify compile error.
// ============================================================================

enum V4_Foo {}
enum V4_Bar {}

// Cross-domain rejection verified — both produce compile errors:
// let v4bad = V3_TaggedOrd<V4_Foo>(position: 1) + V3_TaggedCard<V4_Bar>(count: 1)
// → error: requires types 'V4_Foo' and 'V4_Bar' be equivalent
//
// let v4bad2 = V3_Ordinal(position: 1) + V3_TaggedCard<V4_Foo>(count: 1)
// → error: requires types 'Never' and 'V4_Foo' be equivalent

print("V4: CONFIRMED — cross-domain rejection (Foo≠Bar, Never≠Foo)")

// ============================================================================
// MARK: - Variant 5: Full scenario — Ordinal.Protocol + Cardinal.Protocol + Vector.Protocol
// Hypothesis: The complete Phase 2 design from protocol-abstraction-for-phantom-typed-wrappers
//             works with real Domain: ~Copyable associated types.
// ============================================================================

protocol OrdinalProtocol: ~Copyable {
    associatedtype Domain: ~Copyable
    associatedtype Count: CardinalProtocol where Count.Domain == Domain
    var ordinal: Int { get }
    init(ordinal: Int)
}

protocol CardinalProtocol: ~Copyable {
    associatedtype Domain: ~Copyable
    var cardinal: Int { get }
    init(cardinal: Int)
}

protocol VectorProtocol: ~Copyable {
    associatedtype Domain: ~Copyable
    var vector: Int { get }
    init(vector: Int)
}

// --- Bare types ---

struct BareOrdinal: OrdinalProtocol {
    typealias Domain = Never
    typealias Count = BareCardinal
    var ordinal: Int
    init(ordinal: Int) { self.ordinal = ordinal }
}

struct BareCardinal: CardinalProtocol {
    typealias Domain = Never
    var cardinal: Int
    init(cardinal: Int) { self.cardinal = cardinal }
}

struct BareVector: VectorProtocol {
    typealias Domain = Never
    var vector: Int
    init(vector: Int) { self.vector = vector }
}

// --- Tagged types ---

struct TaggedOrdinal<Tag: ~Copyable>: OrdinalProtocol {
    typealias Domain = Tag
    typealias Count = TaggedCardinal<Tag>
    var ordinal: Int
    init(ordinal: Int) { self.ordinal = ordinal }
}

struct TaggedCardinal<Tag: ~Copyable>: CardinalProtocol {
    typealias Domain = Tag
    var cardinal: Int
    init(cardinal: Int) { self.cardinal = cardinal }
}

struct TaggedVector<Tag: ~Copyable>: VectorProtocol {
    typealias Domain = Tag
    var vector: Int
    init(vector: Int) { self.vector = vector }
}

// --- Cross-type operators: Ordinal + Cardinal → Ordinal ---

func + <O: OrdinalProtocol, C: CardinalProtocol>(
    lhs: O, rhs: C
) -> O where O.Domain == C.Domain {
    O(ordinal: lhs.ordinal + rhs.cardinal)
}

// --- Cross-type operators: Ordinal + Count → Ordinal (via companion) ---

func + <O: OrdinalProtocol>(lhs: O, rhs: O.Count) -> O {
    O(ordinal: lhs.ordinal + rhs.cardinal)
}

// --- Cross-type operators: Ordinal - Ordinal → Vector ---

func - <O: OrdinalProtocol, V: VectorProtocol>(
    lhs: O, rhs: O
) -> V where V.Domain == O.Domain {
    V(vector: lhs.ordinal - rhs.ordinal)
}

// --- Same-type operators: Cardinal + Cardinal ---

func + <C: CardinalProtocol>(lhs: C, rhs: C) -> C {
    C(cardinal: lhs.cardinal + rhs.cardinal)
}

// --- Same-type operators: Vector + Vector, Vector - Vector ---

func + <V: VectorProtocol>(lhs: V, rhs: V) -> V {
    V(vector: lhs.vector + rhs.vector)
}

func - <V: VectorProtocol>(lhs: V, rhs: V) -> V {
    V(vector: lhs.vector - rhs.vector)
}

// --- Cross-type comparison: Ordinal < Cardinal ---

func < <O: OrdinalProtocol, C: CardinalProtocol>(
    lhs: O, rhs: C
) -> Bool where O.Domain == C.Domain {
    lhs.ordinal < rhs.cardinal
}

// --- Test bare types ---

let o1 = BareOrdinal(ordinal: 5) + BareCardinal(cardinal: 3)
print("V5 bare ord+card: \(o1.ordinal)")

let c1 = BareCardinal(cardinal: 10) + BareCardinal(cardinal: 5)
print("V5 bare card+card: \(c1.cardinal)")

let v1 = BareVector(vector: 3) + BareVector(vector: 7)
print("V5 bare vec+vec: \(v1.vector)")

let cmp1 = BareOrdinal(ordinal: 3) < BareCardinal(cardinal: 5)
print("V5 bare ord<card: \(cmp1)")

// --- Test tagged types ---

enum Element {}

let o2 = TaggedOrdinal<Element>(ordinal: 10) + TaggedCardinal<Element>(cardinal: 7)
print("V5 tagged ord+card: \(o2.ordinal)")

let c2 = TaggedCardinal<Element>(cardinal: 20) + TaggedCardinal<Element>(cardinal: 5)
print("V5 tagged card+card: \(c2.cardinal)")

let v2 = TaggedVector<Element>(vector: 1) + TaggedVector<Element>(vector: -3)
print("V5 tagged vec+vec: \(v2.vector)")

let cmp2 = TaggedOrdinal<Element>(ordinal: 3) < TaggedCardinal<Element>(cardinal: 5)
print("V5 tagged ord<card: \(cmp2)")

// --- Test Count companion type ---

let o3 = BareOrdinal(ordinal: 5) + BareCardinal(cardinal: 10)
print("V5 bare ord+count: \(o3.ordinal)")

let o4 = TaggedOrdinal<Element>(ordinal: 5) + TaggedCardinal<Element>(cardinal: 10)
print("V5 tagged ord+count: \(o4.ordinal)")

// --- Test Ordinal - Ordinal → Vector ---

let diff1: BareVector = BareOrdinal(ordinal: 10) - BareOrdinal(ordinal: 3)
print("V5 bare ord-ord: \(diff1.vector)")

let diff2: TaggedVector<Element> = TaggedOrdinal<Element>(ordinal: 10) - TaggedOrdinal<Element>(ordinal: 3)
print("V5 tagged ord-ord: \(diff2.vector)")

print("V5: CONFIRMED — full Phase 2 scenario compiles and runs")

// ============================================================================
// MARK: - Variant 6: ~Copyable Tag (the actual blocker scenario)
// Hypothesis: A noncopyable tag type works as Domain witness.
//             This is the scenario that REQUIRED Domain: ~Copyable.
// ============================================================================

struct MoveOnlyTag: ~Copyable {}

let o5 = TaggedOrdinal<MoveOnlyTag>(ordinal: 100) + TaggedCardinal<MoveOnlyTag>(cardinal: 42)
print("V6 ~Copyable tag ord+card: \(o5.ordinal)")

let cmp3 = TaggedOrdinal<MoveOnlyTag>(ordinal: 3) < TaggedCardinal<MoveOnlyTag>(cardinal: 5)
print("V6 ~Copyable tag ord<card: \(cmp3)")

let diff3: TaggedVector<MoveOnlyTag> = TaggedOrdinal<MoveOnlyTag>(ordinal: 50) - TaggedOrdinal<MoveOnlyTag>(ordinal: 20)
print("V6 ~Copyable tag ord-ord: \(diff3.vector)")

print("V6: CONFIRMED — ~Copyable tag works as Domain witness")

// ============================================================================
// MARK: - Results Summary
// ============================================================================
print("")
print("=== RESULTS ===")
print("V1: associatedtype Domain: ~Copyable compiles")
print("V2: Tagged wrapper conforms with Domain = Tag")
print("V3: Cross-type operators with Domain constraint work")
print("V4: Cross-domain rejection (manual, uncomment to verify)")
print("V5: Full Phase 2 scenario (Ordinal + Cardinal + Vector)")
print("V6: ~Copyable tag as Domain witness")
