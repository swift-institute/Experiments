// MARK: - Dual conformance: Carrier & Mutable
//
// Purpose: Verify that a single concrete type can conform to both
//          `Carrier` (read-only capability over Underlying) and `Mutable`
//          (read+write capability over Value) simultaneously, with
//          Underlying == Value, and that generic algorithms over
//          `T: Carrier & Mutable where T.Underlying == T.Value`
//          typecheck and execute. This is the principled-future-shape
//          composition that motivates the orthogonal stance per
//          `swift-carrier-primitives/Research/mutability-design-space.md`
//          option C.
// Hypothesis: Dual conformance compiles; generic algorithms accepting
//             `inout some Carrier<T> & Mutable<T>` resolve through both
//             accessor surfaces. The two protocols overlap structurally
//             (both have a `borrowing get` over their associated type)
//             but live as siblings, not refining one another.
//
// Toolchain: Swift 6.3.1 (swiftlang-6.3.1.1.2)
// Platform: macOS 26.0 (arm64)
//
// Status: CONFIRMED. Dual conformance compiles and executes for both
//         Copyable and ~Copyable Self. The two protocols compose
//         cleanly without refining one another. Generic algorithms
//         constrained on `T: Carrier<Int> & Mutable<Int>` (with the
//         optional `T.Underlying == T.Value` same-type constraint)
//         resolve through both accessor surfaces — read via
//         `t.underlying` and write via `t.value = ...`. Trivial-self
//         conformers (Int) pick up defaults from both protocols with
//         single-line typealiases. Release build also passes.
// Result: CONFIRMED. Output:
//           V1 dual: Carrier.underlying = 42; Mutable.value (after +5) = 105
//           V2 generic Carrier&Mutable: c.value = 14; c.underlying = 14
//           V3 ~Copyable dual: u.underlying = 13; u.value (after +7) = 20
//           V4 ~Copyable generic: u.value = 101; u.underlying = 101
//           V5 trivial-self Int: i.underlying = 99; j.value (after +1) = 51
// Date: 2026-04-25

// MARK: - Carrier protocol mirror

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
    public var underlying: Self { _read { yield self } }
    public init(_ underlying: consuming Self) { self = underlying }
}

// MARK: - Mutable protocol mirror

public protocol Mutable<Value>: ~Copyable, ~Escapable {
    associatedtype Value: ~Copyable & ~Escapable

    var value: Value {
        @_lifetime(borrow self)
        borrowing get
        set
    }
}

extension Mutable where Value == Self {
    public var value: Self {
        _read { yield self }
        _modify { yield &self }
    }
}

// MARK: - Variant 1: Concrete type conforming to both Carrier and Mutable

struct CounterBox {
    var raw: Int
    init(_ underlying: consuming Int) { self.raw = underlying }
}

extension CounterBox: Carrier {
    typealias Underlying = Int
    var underlying: Int { borrowing get { raw } }
}

extension CounterBox: Mutable {
    typealias Value = Int
    var value: Int {
        _read { yield raw }
        _modify { yield &raw }
    }
}

func runV1() {
    let c = CounterBox(42)
    print("V1 dual: Carrier.underlying = \(c.underlying)")
    var c2 = CounterBox(100)
    c2.value += 5
    print("V1 dual: Mutable.value (after +5) = \(c2.value)")
}

// MARK: - Variant 2: Generic algorithm over both protocols
// `T: Carrier & Mutable where T.Underlying == T.Value` — the canonical
// shape from mutability-design-space.md option C.

func transform<T: Carrier & Mutable>(_ t: inout T) where T.Underlying == T.Value, T.Underlying == Int {
    // Read via Carrier surface.
    let snapshot = t.underlying
    // Write via Mutable surface (Underlying == Value, so the same Int field).
    t.value = snapshot * 2
}

func runV2() {
    var c = CounterBox(7)
    transform(&c)
    print("V2 generic Carrier&Mutable: c.value = \(c.value); c.underlying = \(c.underlying)")
}

// MARK: - Variant 3: ~Copyable dual conformance
// Tests dual conformance when Self is ~Copyable.

struct UniqueBox: ~Copyable {
    var _storage: Int
    init(_ underlying: consuming Int) { self._storage = underlying }
}

extension UniqueBox: Carrier {
    typealias Underlying = Int
    var underlying: Int { _read { yield _storage } }
}

extension UniqueBox: Mutable {
    typealias Value = Int
    var value: Int {
        _read { yield _storage }
        _modify { yield &_storage }
    }
}

func runV3() {
    var u = UniqueBox(13)
    print("V3 ~Copyable dual: u.underlying = \(u.underlying)")
    u.value += 7
    print("V3 ~Copyable dual: u.value (after +7) = \(u.value)")
}

// MARK: - Variant 4: Generic algorithm spanning ~Copyable conformers
// Demonstrates that the dual-conformance bound works for ~Copyable Self.

func transformUnique<T: Carrier<Int> & Mutable<Int> & ~Copyable>(_ t: inout T) {
    let snapshot = t.underlying
    t.value = snapshot &+ 100
}

func runV4() {
    var u = UniqueBox(1)
    transformUnique(&u)
    print("V4 ~Copyable generic: u.value = \(u.value); u.underlying = \(u.underlying)")
}

// MARK: - Variant 5: Trivial-self Int conforms to both
// Defaults from `where Underlying == Self` (Carrier) and
// `where Value == Self` (Mutable). One-line opt-in per protocol.

extension Int: Carrier {
    public typealias Underlying = Int
}

extension Int: Mutable {
    public typealias Value = Int
}

func runV5() {
    let i: Int = 99
    print("V5 trivial-self Int: i.underlying = \(i.underlying)")
    var j: Int = 50
    j.value += 1
    print("V5 trivial-self Int: j.value (after +1) = \(j.value)")
}

// MARK: - Main

runV1()
runV2()
runV3()
runV4()
runV5()
