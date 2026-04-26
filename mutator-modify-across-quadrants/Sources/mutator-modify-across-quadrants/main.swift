// MARK: - Modify across the four Copyable × Escapable quadrants
//
// Purpose: Determine whether sibling default extensions on `Mutator`'s
//          canonical capability protocol — each with its own constraint
//          suppression — can provide read+modify access for trivial-self
//          conformers across all four (Copyable | ~Copyable) × (Escapable
//          | ~Escapable) quadrants. Mirrors the read-only pattern
//          empirically established for `Carrier` in
//          `swift-carrier-primitives/Experiments/relax-trivial-self-default/`.
//
// Hypothesis A: A protocol property requirement of `borrowing get` +
//               `set` admits implementations using `_read`/`_modify`
//               coroutine syntax, including for `~Copyable` Value.
// Hypothesis B: Four sibling default extensions (Q1: bare; Q2: ~Copyable;
//               Q3: ~Escapable; Q4: ~Copyable & ~Escapable) provide
//               working `_read`/`_modify` witnesses. Q1/Q2 require no
//               `@_lifetime` annotations (Self is Escapable so lifetime
//               annotations on Self-typed result are rejected). Q3/Q4
//               require `@_lifetime(borrow self)` on `_read` and
//               `@_lifetime(&self)` on `_modify` because the result type
//               is ~Escapable.
//
// Toolchain: Swift 6.3.1 (swiftlang-6.3.1.1.2)
// Platform: macOS 26.0 (arm64)
//
// Status: CONFIRMED with REFUTED sub-finding on protocol requirement
//         shape: `mutating _modify` is NOT a valid protocol property
//         requirement (Swift accepts only `get`/`set`). The revised
//         protocol uses `borrowing get` + `set` as requirements; the
//         implementation side uses `_read`/`_modify` coroutines, which
//         satisfy those requirements including for ~Copyable Value.
//         Cross-module + release passes per [EXP-017]. Output:
//           V1 Q1: c.value.raw = 12
//           V2 Q2: c.value.raw = 17
//           V3 Q3: span.value.count = 3
//           V4 Q4: h.value.raw = 28
//           V5 distinct ~Copyable Value: box.value.raw = 123
//           [cross-module] Q1: 8, Q2: 15, Q3: 3, Q4: 24, distinct: 105
// Result: CONFIRMED — four-quadrant trivial-self default extensions
//         provide working `_read`/`_modify` witnesses for the `Mutable`
//         protocol. Q1/Q2 require no `@_lifetime` annotations; Q3/Q4
//         require `@_lifetime(borrow self)` on `_read` and
//         `@_lifetime(&self)` on `_modify` (NOT `@_lifetime(borrow
//         self)` — Swift explicitly rejects `borrow` for inout-ownership
//         dependencies and directs to `&self`). Generic dispatch through
//         `inout some Mutable<T>` requires explicit `& ~Copyable` /
//         `& ~Escapable` suppression on the generic constraint to
//         accept Q2/Q4 conformers — without suppression, Swift defaults
//         to Copyable & Escapable.
// Date: 2026-04-25

// MARK: - Mutable protocol mirror
//
// Uses the `borrowing get` + `set` requirement form (not `_modify`); the
// implementation side uses `_read`/`_modify` coroutines, which satisfy
// `borrowing get`/`set` respectively. The `@_lifetime` annotations on
// the protocol's set requirement use `&self` for inout dependence.

public protocol Mutable<Value>: ~Copyable, ~Escapable {
    associatedtype Value: ~Copyable & ~Escapable

    var value: Value {
        @_lifetime(borrow self)
        borrowing get
        set
    }
}

// MARK: - Sibling default extensions, per quadrant
//
// The implementation uses `_read`/`_modify` (coroutine form) to satisfy
// the protocol's `borrowing get`/`set` requirement. This is necessary
// for ~Copyable Value: a plain `set { ... }` body would have to consume
// the existing value, which a borrow-get cannot reproduce.

// Q1 — Copyable & Escapable Self.
extension Mutable where Value == Self {
    public var value: Self {
        _read { yield self }
        _modify { yield &self }
    }
}

// Q2 — ~Copyable, Escapable Self.
extension Mutable where Value == Self, Self: ~Copyable {
    public var value: Self {
        _read { yield self }
        _modify { yield &self }
    }
}

// Q3 — Copyable, ~Escapable Self.
extension Mutable where Value == Self, Self: ~Escapable {
    public var value: Self {
        @_lifetime(borrow self)
        _read { yield self }
        @_lifetime(&self)
        _modify { yield &self }
    }
}

// Q4 — ~Copyable & ~Escapable Self.
extension Mutable where Value == Self, Self: ~Copyable & ~Escapable {
    public var value: Self {
        @_lifetime(borrow self)
        _read { yield self }
        @_lifetime(&self)
        _modify { yield &self }
    }
}

// MARK: - Variant 1: Q1 conformer (Copyable & Escapable Self)

struct Counter: Mutable {
    typealias Value = Counter
    var raw: Int
}

func runV1() {
    var c = Counter(raw: 7)
    c.value.raw += 5
    print("V1 Q1: c.value.raw = \(c.value.raw)")
}

// MARK: - Variant 2: Q2 conformer (~Copyable, Escapable Self)

struct UniqueCounter: ~Copyable, Mutable {
    typealias Value = UniqueCounter
    var raw: Int
}

func runV2() {
    var c = UniqueCounter(raw: 13)
    c.value.raw += 4
    print("V2 Q2: c.value.raw = \(c.value.raw)")
}

// MARK: - Variant 3: Q3 conformer (Copyable, ~Escapable Self) via MutableSpan

extension MutableSpan: Mutable {
    public typealias Value = MutableSpan<Element>
}

func runV3() {
    var bytes: [UInt8] = [10, 20, 30]
    bytes.withUnsafeMutableBufferPointer { buffer in
        let span = MutableSpan<UInt8>(_unsafeElements: buffer)
        let count = span.value.count
        // Mutating span.value would require span itself to be `var` and the
        // assignment to flow through `_modify`. The Q3 default's `_modify`
        // yields a `~Escapable` self by inout — semantically valid, though
        // a typical Q3 mutation is via the type's own API rather than the
        // protocol surface.
        print("V3 Q3: span.value.count = \(count)")
    }
}

// MARK: - Variant 4: Q4 conformer (~Copyable & ~Escapable Self)

struct ScopedHandle: ~Copyable, ~Escapable, Mutable {
    typealias Value = ScopedHandle
    var raw: Int
}

func runV4() {
    var h = ScopedHandle(raw: 21)
    h.value.raw += 7
    print("V4 Q4: h.value.raw = \(h.value.raw)")
}

// MARK: - Variant 5: ~Copyable Value distinct from Self
// Tests that explicit witnesses (when Value != Self) compose correctly
// across `_read`/`_modify` coroutine satisfaction of the protocol's
// `borrowing get`/`set` requirement.

struct RawDescriptor: ~Copyable {
    var raw: Int32
}

struct DescriptorBox: ~Copyable {
    var _storage: RawDescriptor
    init(_ storage: consuming RawDescriptor) { self._storage = storage }
}

extension DescriptorBox: Mutable {
    typealias Value = RawDescriptor
    var value: RawDescriptor {
        _read { yield _storage }
        _modify { yield &_storage }
    }
}

func runV5() {
    var box = DescriptorBox(RawDescriptor(raw: 100))
    box.value.raw += 23
    print("V5 distinct ~Copyable Value: box.value.raw = \(box.value.raw)")
}

// MARK: - Main

runV1()
runV2()
runV3()
runV4()
runV5()
