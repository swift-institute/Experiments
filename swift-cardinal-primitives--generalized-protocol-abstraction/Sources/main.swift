// MARK: - Generalized Protocol Abstraction Experiment
// Purpose: Test whether the X.Protocol pattern (Cardinal.Protocol, Ordinal.Protocol)
//          can be unified into a single generic mechanism
// Hypothesis: A generic protocol with primary associated type can replace
//             per-type protocol definitions while preserving type-preserving generics
//
// Toolchain: Apple Swift 6.2.3
// Platform: macOS 26 (arm64)
//
// Result: CONFIRMED — All 11 variants compile and run correctly (V9 REFUTED as expected).
//
//   V1  (baseline per-type protocols):  CONFIRMED — type-preserving, ergonomic
//   V2  (Representable assoc type):     CONFIRMED — works but verbose constraints
//   V3  (Optic.Iso value witness):      CONFIRMED — works but requires passing iso explicitly
//   V4  (RepresentedBy<Base> primary):  CONFIRMED — cleanest generic unification
//   V5  (generic operators):            CONFIRMED — operators generic over RepresentedBy<Cardinal>
//   V6  (ergonomics):                   .cardinal vs .underlying — domain-specific wins
//   V7  (mixed cross-type ops):         CONFIRMED — composes across different Underlying types
//   V8  (coexistence):                  CONFIRMED — both patterns can coexist on same type
//   V9  (Tagged.Protocol nested):       REFUTED  — protocol cannot nest in generic type
//   V9a (Taggable<Value> top-level):    CONFIRMED — full unification with primary assoc type
//   V10 (domain-specific accessors):    CONFIRMED — .cardinal/.ordinal via conditional extension on Taggable
//   V11 (static members):              CONFIRMED — .zero/.one via conditional extension on Taggable
//
// KEY FINDING: Tagged.Protocol is impossible (Swift restriction). But Taggable<Value>
// (V9a) achieves the same goal as a top-level protocol. Combined with V10's conditional
// extensions, it provides BOTH the unified protocol AND domain-specific accessors
// (.value AND .cardinal available simultaneously). V11 shows static members work too.
//
// The question becomes: Taggable<Value> (one protocol, conditional extensions for
// domain accessors) vs per-type X.Protocol (N protocols, built-in domain accessors).
// Taggable is DRY; X.Protocol is explicit. Both work.
//
// Date: 2026-02-04

// =============================================================================
// MARK: - Minimal reproductions of the types involved
// =============================================================================

/// Minimal Cardinal (UInt-backed quantity)
struct Cardinal: Hashable, Sendable {
    let rawValue: UInt
    init(_ value: UInt) { self.rawValue = value }
}

/// Minimal Ordinal (UInt-backed position)
struct Ordinal: Hashable, Sendable {
    let rawValue: UInt
    init(_ value: UInt) { self.rawValue = value }
}

/// Minimal Tagged (phantom-typed wrapper) — simplified for this experiment
struct Tagged<Tag, RawValue> {
    let rawValue: RawValue
    init(__unchecked: Void = (), _ rawValue: RawValue) { self.rawValue = rawValue }
}
extension Tagged: Sendable where RawValue: Sendable {}
extension Tagged: Equatable where RawValue: Equatable {}
extension Tagged: Hashable where RawValue: Hashable {}

// =============================================================================
// MARK: - Variant 1: Current pattern (baseline) — per-type protocols
// =============================================================================

// Hypothesis: This is what we have. Works, but requires N protocol definitions.
// Result: CONFIRMED — type-preserving generics work, ergonomic .cardinal/.ordinal accessors

extension Cardinal {
    protocol `Protocol` {
        var cardinal: Cardinal { get }
        init(_ cardinal: Cardinal)
    }
}

extension Cardinal: Cardinal.`Protocol` {
    var cardinal: Cardinal { self }
    init(_ cardinal: Cardinal) { self = cardinal }
}

extension Tagged: Cardinal.`Protocol` where RawValue == Cardinal {
    var cardinal: Cardinal { rawValue }
    init(_ cardinal: Cardinal) { self.init(__unchecked: (), cardinal) }
}

extension Ordinal {
    protocol `Protocol` {
        var ordinal: Ordinal { get }
        init(_ ordinal: Ordinal)
    }
}

extension Ordinal: Ordinal.`Protocol` {
    var ordinal: Ordinal { self }
    init(_ ordinal: Ordinal) { self = ordinal }
}

extension Tagged: Ordinal.`Protocol` where RawValue == Ordinal {
    var ordinal: Ordinal { rawValue }
    init(_ ordinal: Ordinal) { self.init(__unchecked: (), ordinal) }
}

/// Baseline: type-preserving generic function
func addOne_baseline<C: Cardinal.`Protocol`>(_ value: C) -> C {
    C(Cardinal(value.cardinal.rawValue + 1))
}

// =============================================================================
// MARK: - Variant 2: Generic Representable protocol (associated type)
// =============================================================================

// Hypothesis: A single protocol with an associated type can replace all X.Protocol.
// Key question: Can Tagged conditionally conform with different associated types
// for different RawValue types? Answer: YES, via transitive conformance.
// Result: CONFIRMED — works via transitive conformance, but constraint syntax is verbose

protocol Representable {
    associatedtype Representation
    var representation: Representation { get }
    init(representation: Representation)
}

extension Cardinal: Representable {
    typealias Representation = Cardinal
    var representation: Cardinal { self }
    init(representation: Cardinal) { self = representation }
}

extension Ordinal: Representable {
    typealias Representation = Ordinal
    var representation: Ordinal { self }
    init(representation: Ordinal) { self = representation }
}

// Transitive conformance: Tagged inherits Representation from RawValue
extension Tagged: Representable where RawValue: Representable {
    typealias Representation = RawValue.Representation
    var representation: RawValue.Representation { rawValue.representation }
    init(representation: RawValue.Representation) {
        self.init(__unchecked: (), RawValue(representation: representation))
    }
}

func addOne_representable<R: Representable>(_ value: R) -> R where R.Representation == Cardinal {
    R(representation: Cardinal(value.representation.rawValue + 1))
}

// =============================================================================
// MARK: - Variant 3: Optic.Iso as value witness (no protocol)
// =============================================================================

// Hypothesis: Instead of a protocol, pass an Optic.Iso<T, Cardinal> as a parameter.
// This avoids protocol proliferation but requires passing the iso explicitly.
// Result: CONFIRMED — works but shifts complexity to every call site

struct Iso<Whole, Part>: Sendable {
    let forward: @Sendable (Whole) -> Part
    let backward: @Sendable (Part) -> Whole
}

let cardinalIso = Iso<Cardinal, Cardinal>(
    forward: { $0 },
    backward: { $0 }
)

func taggedCardinalIso<Tag>() -> Iso<Tagged<Tag, Cardinal>, Cardinal> {
    Iso(
        forward: { $0.rawValue },
        backward: { Tagged($0) }
    )
}

func addOne_iso<T>(_ value: T, via iso: Iso<T, Cardinal>) -> T {
    iso.backward(Cardinal(iso.forward(value).rawValue + 1))
}

// =============================================================================
// MARK: - Variant 4: Primary associated type — RepresentedBy<Base>
// =============================================================================

// Hypothesis: Use primary associated type syntax for cleaner constraints.
// `some RepresentedBy<Cardinal>` instead of `where R.Representation == Cardinal`
// Result: CONFIRMED — cleanest unification; constraint reads RepresentedBy<Cardinal>

protocol RepresentedBy<Underlying> {
    associatedtype Underlying
    var underlying: Underlying { get }
    init(underlying: Underlying)
}

extension Cardinal: RepresentedBy {
    typealias Underlying = Cardinal
    var underlying: Cardinal { self }
    init(underlying: Cardinal) { self = underlying }
}

extension Ordinal: RepresentedBy {
    typealias Underlying = Ordinal
    var underlying: Ordinal { self }
    init(underlying: Ordinal) { self = underlying }
}

// Transitive Tagged conformance
extension Tagged: RepresentedBy where RawValue: RepresentedBy {
    typealias Underlying = RawValue.Underlying
    var underlying: RawValue.Underlying { rawValue.underlying }
    init(underlying: RawValue.Underlying) { self.init(__unchecked: (), RawValue(underlying: underlying)) }
}

// Type-preserving generic with primary associated type:
func addOne_primary<R: RepresentedBy<Cardinal>>(_ value: R) -> R {
    R(underlying: Cardinal(value.underlying.rawValue + 1))
}

// Works for Ordinal too:
func successor_primary<R: RepresentedBy<Ordinal>>(_ value: R) -> R {
    R(underlying: Ordinal(value.underlying.rawValue + 1))
}

// =============================================================================
// MARK: - Variant 5: Operators generic over RepresentedBy<Cardinal>
// =============================================================================

// Hypothesis: Operators like + can be defined once for all RepresentedBy<Cardinal>.
// Result: CONFIRMED — single operator definition works for both Cardinal and Tagged

func + <C: RepresentedBy<Cardinal>>(lhs: C, rhs: C) -> C {
    C(underlying: Cardinal(lhs.underlying.rawValue + rhs.underlying.rawValue))
}

func += <C: RepresentedBy<Cardinal>>(lhs: inout C, rhs: C) {
    lhs = lhs + rhs
}

// Cross-type: RepresentedBy<Ordinal> displacement
func displacement<O: RepresentedBy<Ordinal>>(from: O, to: O) -> Int {
    Int(to.underlying.rawValue) - Int(from.underlying.rawValue)
}

// =============================================================================
// MARK: - Variant 6: Ergonomics comparison
// =============================================================================

// Hypothesis: `.underlying` is less readable than `.cardinal` at call sites.
// Result: CONFIRMED — .cardinal conveys domain meaning; .underlying is generic/opaque

// With current pattern:
func example_current<C: Cardinal.`Protocol`>(_ c: C) {
    let _ = c.cardinal          // Clear: this is a Cardinal
    let _ = c.cardinal.rawValue // Clear chain
}

// With generic pattern:
func example_generic<C: RepresentedBy<Cardinal>>(_ c: C) {
    let _ = c.underlying          // What is "underlying"? Less clear.
    let _ = c.underlying.rawValue // OK but `.underlying` is generic
}

// =============================================================================
// MARK: - Variant 7: Can the Representable approach handle MIXED operations?
// =============================================================================

// Hypothesis: Operations like Ordinal + Cardinal → Ordinal require constraints
// on TWO different RepresentedBy types. Test if this composes.
// Result: CONFIRMED — cross-type ops compose cleanly with two generic parameters

func advance<O: RepresentedBy<Ordinal>, C: RepresentedBy<Cardinal>>(_ position: O, by count: C) -> O {
    O(underlying: Ordinal(position.underlying.rawValue + count.underlying.rawValue))
}

// =============================================================================
// MARK: - Variant 8: Does RepresentedBy compose with the existing X.Protocol?
// =============================================================================

// Hypothesis: Can a type conform to BOTH Cardinal.Protocol AND RepresentedBy<Cardinal>?
// This tests coexistence during migration.
// Result: CONFIRMED — both protocols can coexist on same type without conflict

// Cardinal already conforms to both (defined above).
// Let's verify we can use either constraint:
func useBoth_cardinal<C: Cardinal.`Protocol` & RepresentedBy<Cardinal>>(_ c: C) -> C {
    // Can access via either interface
    let viaProtocol = c.cardinal.rawValue
    let viaGeneric = c.underlying.rawValue
    assert(viaProtocol == viaGeneric)
    return C(Cardinal(viaProtocol + 1))
}

// =============================================================================
// MARK: - Variant 9: Tagged.Protocol — REFUTED
// =============================================================================

// Hypothesis: Define `Tagged.Protocol<Value>` nested inside Tagged.
//
// Result: REFUTED — Swift error: "protocol cannot be nested in a generic context"
//
// Tagged is `struct Tagged<Tag, RawValue>` — a generic type. Swift does not
// allow protocols to be nested inside generic types. This is a hard language
// constraint with no workaround via `extension Tagged { protocol ... }`.
//
// Alternatives tested below:
// V9a: Non-generic namespace enum alongside Tagged
// V9b: Top-level protocol with "Tagged" in the name

// =============================================================================
// MARK: - Variant 9a: Taggable<Value> — top-level protocol
// =============================================================================

// Hypothesis: Define a top-level protocol with primary associated type.
// Since it can't nest inside Tagged, give it a name that conveys the
// relationship: "types that can be tagged" = Taggable.
//
// Result: CONFIRMED — full unification: type-preserving, single Tagged conformance

protocol Taggable<Value> {
    associatedtype Value
    var value: Value { get }
    init(_ value: Value)
}

// Self-conformance: Cardinal is Taggable<Cardinal>
extension Cardinal: Taggable {
    typealias Value = Cardinal
    var value: Cardinal { self }
    // init(_ cardinal: Cardinal) already satisfied by Cardinal.Protocol (V1)
}

// Self-conformance: Ordinal is Taggable<Ordinal>
extension Ordinal: Taggable {
    typealias Value = Ordinal
    var value: Ordinal { self }
    // init(_ ordinal: Ordinal) already satisfied by Ordinal.Protocol (V1)
}

// Tagged conformance: single definition handles all RawValue types
extension Tagged: Taggable where RawValue: Taggable {
    typealias Value = RawValue.Value
    var value: RawValue.Value { rawValue.value }
    init(_ value: RawValue.Value) { self.init(__unchecked: (), RawValue(value)) }
}

// Type-preserving generic function:
func addOne_taggable<C: Taggable<Cardinal>>(_ value: C) -> C {
    C(Cardinal(value.value.rawValue + 1))
}

// Ordinal version:
func successor_taggable<O: Taggable<Ordinal>>(_ value: O) -> O {
    O(Ordinal(value.value.rawValue + 1))
}

// Generic operator (named differently to avoid conflict with V5):
func taggableAdd<C: Taggable<Cardinal>>(_ lhs: C, _ rhs: C) -> C {
    C(Cardinal(lhs.value.rawValue + rhs.value.rawValue))
}

// Mixed cross-type operation:
func advance_taggable<O: Taggable<Ordinal>, C: Taggable<Cardinal>>(
    _ position: O, by count: C
) -> O {
    O(Ordinal(position.value.rawValue + count.value.rawValue))
}

// =============================================================================
// MARK: - Variant 10: Domain-specific accessors via conditional extensions
// =============================================================================

// Hypothesis: We can restore .cardinal/.ordinal as computed properties on
// Taggable where Value == Cardinal, giving us BOTH .value AND .cardinal.
//
// Result: CONFIRMED — .value and .cardinal both available, no conflict

extension Taggable where Value == Cardinal {
    var cardinal: Cardinal { value }
}

extension Taggable where Value == Ordinal {
    var ordinal: Ordinal { value }
}

// Now: do we get both .value AND .cardinal?
func example_taggable<C: Taggable<Cardinal>>(_ c: C) {
    let _ = c.value             // generic accessor (always available)
    let _ = c.cardinal          // domain-specific (via conditional extension)
    let _ = c.cardinal.rawValue // full chain
}

// =============================================================================
// MARK: - Variant 11: Static members on Taggable
// =============================================================================

// Hypothesis: .zero and .one can be defined on Taggable<Cardinal>.
//
// Result: CONFIRMED — static members work via conditional extension
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES

extension Taggable where Value == Cardinal {
    static var zero: Self { Self(Cardinal(0)) }
    static var one: Self { Self(Cardinal(1)) }
}

extension Taggable where Value == Ordinal {
    static var zero: Self { Self(Ordinal(0)) }
}

// =============================================================================
// MARK: - Execution
// =============================================================================

enum StorageTag {}

func main() {
    // --- Variant 1: Baseline ---
    let c1 = Cardinal(5)
    let tc1 = Tagged<StorageTag, Cardinal>(Cardinal(5))
    let r1a = addOne_baseline(c1)
    let r1b = addOne_baseline(tc1)
    print("V1 baseline:      Cardinal \(r1a.rawValue), Tagged \(r1b.rawValue)")
    print("  Type preserved: \(type(of: r1a) == Cardinal.self), \(type(of: r1b) == Tagged<StorageTag, Cardinal>.self)")

    // --- Variant 2: Representable ---
    let r2a = addOne_representable(c1)
    let r2b = addOne_representable(tc1)
    print("V2 representable: Cardinal \(r2a.rawValue), Tagged \(r2b.rawValue)")
    print("  Type preserved: \(type(of: r2a) == Cardinal.self), \(type(of: r2b) == Tagged<StorageTag, Cardinal>.self)")

    // --- Variant 3: Iso value ---
    let r3a = addOne_iso(c1, via: cardinalIso)
    let r3b: Tagged<StorageTag, Cardinal> = addOne_iso(tc1, via: taggedCardinalIso())
    print("V3 iso value:     Cardinal \(r3a.rawValue), Tagged \(r3b.rawValue)")

    // --- Variant 4: RepresentedBy primary associated type ---
    let r4a = addOne_primary(c1)
    let r4b = addOne_primary(tc1)
    print("V4 primary:       Cardinal \(r4a.rawValue), Tagged \(r4b.rawValue)")
    print("  Type preserved: \(type(of: r4a) == Cardinal.self), \(type(of: r4b) == Tagged<StorageTag, Cardinal>.self)")

    // Ordinal test
    let o1 = Ordinal(10)
    let to1 = Tagged<StorageTag, Ordinal>(Ordinal(10))
    let r4c = successor_primary(o1)
    let r4d = successor_primary(to1)
    print("  Ordinal:        Ordinal \(r4c.rawValue), Tagged \(r4d.rawValue)")

    // --- Variant 5: Generic operators ---
    let sum = c1 + Cardinal(3)
    let taggedSum = tc1 + Tagged<StorageTag, Cardinal>(Cardinal(3))
    print("V5 operators:     Cardinal \(sum.rawValue), Tagged \(taggedSum.rawValue)")
    print("  Type preserved: \(type(of: sum) == Cardinal.self), \(type(of: taggedSum) == Tagged<StorageTag, Cardinal>.self)")

    // --- Variant 6: Ergonomics ---
    print("V6 ergonomics:    .cardinal = \(c1.cardinal.rawValue), .underlying = \(c1.underlying.rawValue)")

    // --- Variant 7: Mixed operations ---
    let advanced = advance(o1, by: Cardinal(5))
    let advancedTagged = advance(to1, by: Tagged<StorageTag, Cardinal>(Cardinal(5)))
    print("V7 mixed:         Ordinal \(advanced.rawValue), Tagged \(advancedTagged.rawValue)")

    // --- Variant 8: Coexistence ---
    let r8 = useBoth_cardinal(c1)
    let r8t = useBoth_cardinal(tc1)
    print("V8 coexistence:   Cardinal \(r8.rawValue), Tagged \(r8t.rawValue)")

    // --- Variant 9: Taggable ---
    print("V9: Tagged.Protocol REFUTED — cannot nest protocol in generic type")
    let r9a = addOne_taggable(c1)
    let r9b = addOne_taggable(tc1)
    print("V9a Taggable:     Cardinal \(r9a.rawValue), Tagged \(r9b.rawValue)")
    print("  Type preserved: \(type(of: r9a) == Cardinal.self), \(type(of: r9b) == Tagged<StorageTag, Cardinal>.self)")

    // Ordinal
    let r9c = successor_taggable(o1)
    let r9d = successor_taggable(to1)
    print("  Ordinal:        Ordinal \(r9c.rawValue), Tagged \(r9d.rawValue)")

    // Generic operator
    let r9sum = taggableAdd(c1, Cardinal(3))
    let r9tsum = taggableAdd(tc1, Tagged<StorageTag, Cardinal>(Cardinal(3)))
    print("  Operator:       Cardinal \(r9sum.rawValue), Tagged \(r9tsum.rawValue)")

    // Mixed cross-type
    let r9adv = advance_taggable(o1, by: Cardinal(5))
    let r9tadv = advance_taggable(to1, by: Tagged<StorageTag, Cardinal>(Cardinal(5)))
    print("  Mixed:          Ordinal \(r9adv.rawValue), Tagged \(r9tadv.rawValue)")

    // --- Variant 10: Domain-specific accessors on Taggable ---
    print("V10 accessors:    .value = \(c1.value.rawValue), .cardinal = \(c1.cardinal.rawValue)")
    print("  Tagged:         .value = \(tc1.value.rawValue), .cardinal = \(tc1.cardinal.rawValue)")

    // --- Variant 11: Static members ---
    let czero: Cardinal = .zero
    let tczero: Tagged<StorageTag, Cardinal> = .zero
    let ozero: Ordinal = .zero
    let tozero: Tagged<StorageTag, Ordinal> = .zero
    print("V11 statics:      Cardinal.zero = \(czero.rawValue), Tagged.zero = \(tczero.rawValue)")
    print("  Ordinal:        Ordinal.zero = \(ozero.rawValue), Tagged.zero = \(tozero.rawValue)")

    print("\nAll variants executed successfully.")
}

main()
