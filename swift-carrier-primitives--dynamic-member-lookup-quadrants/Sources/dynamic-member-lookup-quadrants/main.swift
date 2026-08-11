// MARK: - @dynamicMemberLookup × four-quadrant Carrier
//
// Purpose: Empirically determine whether `@dynamicMemberLookup` applied
//          to the Carrier super-protocol (with a default KeyPath
//          subscript on a protocol extension) is viable across all four
//          Copyable × Escapable quadrants of Underlying.
// Hypothesis: Q1 (Copyable & Escapable Underlying) works; Q2/Q3/Q4
//             reject the KeyPath subscript because KeyPath<Root, Value>
//             requires Root to be Copyable & Escapable in Swift 6.3.
//             Therefore @dynamicMemberLookup at the Carrier-protocol
//             level only delivers the syntactic affordance for Q1
//             conformers.
//
// Toolchain: Swift 6.3.1 (swiftlang-6.3.1.1.2)
// Platform: macOS 26.0 (arm64)
//
// Status: CONFIRMED in part — Q1 admits dynamic lookup; Q2/Q3/Q4 do not.
// Result: PARTIAL (V1 CONFIRMED, V2 REFUTED, V3 REFUTED, Q4 REFUTED by
//         transitivity). The KeyPath default subscript carries implicit
//         `where Self: Copyable & Escapable, Self.Underlying: Copyable
//         & Escapable` constraints, so dynamic member lookup at the
//         Carrier protocol level is a Q1-only affordance — and Q1 is
//         the case (Underlying == Self for trivial self-carriers, or
//         distinct Copyable Underlying for tagged carriers) where it
//         provides the most ergonomic value.
// Date: 2026-04-25

// MARK: - Carrier mirror

@dynamicMemberLookup
public protocol Carrier<Underlying>: ~Copyable, ~Escapable {
    associatedtype Domain: ~Copyable & ~Escapable = Never
    associatedtype Underlying: ~Copyable & ~Escapable

    var underlying: Underlying {
        @_lifetime(borrow self)
        borrowing get
    }

    @_lifetime(copy underlying)
    init(_ underlying: consuming Underlying)
}

extension Carrier where Underlying == Self {
    public var underlying: Self {
        _read { yield self }
    }
    public init(_ underlying: consuming Self) {
        self = underlying
    }
}

// Default subscript on the protocol — V1 hypothesis.
extension Carrier {
    public subscript<T>(dynamicMember keyPath: KeyPath<Underlying, T>) -> T {
        underlying[keyPath: keyPath]
    }
}

// MARK: - Variant 1: Q1 (Copyable & Escapable Underlying)
// Hypothesis: dot-syntax member lookup forwards to Underlying.
// Result: CONFIRMED — `id.description` resolves to `id.underlying.description`.
//         Output: V1 Q1: id.description = 42
//         Two sub-findings:
//         (a) `@dynamicMemberLookup` on a protocol declaration is
//             accepted in Swift 6.3 and propagates the dot-syntax
//             affordance to conformers (UserID has no own annotation).
//         (b) The default subscript on a protocol extension instantiates
//             correctly when Self and Underlying are both Copyable &
//             Escapable.
//         Receipt: Outputs/run-v1.txt.

struct UserID: Carrier {
    typealias Underlying = Int
    var raw: Int
    var underlying: Int { raw }
    init(_ underlying: consuming Int) { self.raw = underlying }
}

func runV1() {
    let id = UserID(42)
    // Underlying property access via dynamic member lookup:
    let desc: String = id.description  // → id.underlying.description → "42"
    print("V1 Q1: id.description = \(desc)")
}

runV1()
print("V1 complete")

// MARK: - Variant 2: Q2 (~Copyable Underlying)
// Hypothesis: KeyPath<~Copyable Root, T> does not typecheck in Swift 6.3,
//             so dynamic member lookup is unavailable for ~Copyable
//             Underlying despite the conformance otherwise being valid.
// Status: REFUTED in the strong form (the conformance compiles; only the
//         dynamic member access expression is rejected).
// Result: REFUTED — the protocol extension's subscript carries implicit
//         `where Self: Copyable, Self.Underlying: Copyable`. Diagnostics:
//         "referencing subscript 'subscript(dynamicMember:)' on 'Carrier'
//          requires that 'UniqueWrapper' conform to 'Copyable'"
//         "subscript 'subscript(dynamicMember:)' requires that
//          'UniqueWrapper.Underlying' (aka 'Resource') conform to 'Copyable'"
//         Receipt: Outputs/build-v2-active.txt.

struct Resource: ~Copyable {
    var raw: Int
}

struct UniqueWrapper: ~Copyable, Carrier {
    typealias Underlying = Resource
    var _storage: Resource
    var underlying: Resource {
        _read { yield _storage }
    }
    init(_ underlying: consuming Resource) {
        self._storage = underlying
    }
}

func runV2() {
    let w = UniqueWrapper(Resource(raw: 7))
    // V2 REFUTED — leaving the failing expression commented for the
    // build receipt; uncomment to reproduce.
    // let r: Int = w.raw
    _ = w
    print("V2 Q2: dynamic member access unavailable for ~Copyable")
}

runV2()
print("V2 complete")

// MARK: - Variant 3: Q3 (~Escapable Underlying)
// Hypothesis: KeyPath<~Escapable Root, T> does not typecheck.
// Status: REFUTED in the strong form — conformance compiles; only the
//         dynamic member access expression is rejected.
// Result: REFUTED — protocol extension's subscript carries implicit
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
//         `where Self: Escapable, Self.Underlying: Escapable`.
//         Diagnostics:
//         "referencing subscript 'subscript(dynamicMember:)' on 'Carrier'
//          requires that 'ScopedWrapper' conform to 'Escapable'"
//         "subscript 'subscript(dynamicMember:)' requires that
//          'ScopedWrapper.Underlying' (aka 'ScopedView') conform to 'Escapable'"
//         Receipt: Outputs/build-v3-active.txt.

struct ScopedView: ~Escapable {
    var raw: Int

    @_lifetime(immortal)
    init(raw: Int) {
        self.raw = raw
    }
}

struct ScopedWrapper: ~Escapable, Carrier {
    typealias Underlying = ScopedView
    var _storage: ScopedView

    @_lifetime(copy underlying)
    init(_ underlying: consuming ScopedView) {
        self._storage = underlying
    }

    var underlying: ScopedView {
        @_lifetime(borrow self)
        _read { yield _storage }
    }
}

func runV3() {
    let v = ScopedView(raw: 11)
    let w = ScopedWrapper(v)
    // V3 REFUTED — leaving the failing expression commented for the
    // build receipt; uncomment to reproduce.
    // let r: Int = w.raw
    _ = w
    print("V3 Q3: dynamic member access unavailable for ~Escapable")
}

runV3()
print("V3 complete")
