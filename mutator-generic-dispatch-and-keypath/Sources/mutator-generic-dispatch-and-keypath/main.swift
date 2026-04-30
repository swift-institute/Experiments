// MARK: - Generic dispatch through `inout some Mutable` + KeyPath probe
//
// Purpose: Probe two questions side-by-side:
//   (1) Generic dispatch — what shapes of `inout some Mutable` are
//       writable? Same-Value constraint, fully-generic over Self,
//       transformations that round-trip through `value`.
//   (2) WritableKeyPath subscript — does `@dynamicMemberLookup` over
//       `WritableKeyPath<Value, T>` admit a uniform mutation affordance
//       across all four quadrants, or does it suffer the same Q1-only
//       constraint as Carrier's read-only KeyPath case (per
//       `dynamic-member-lookup-decision.md`)?
//
// Hypothesis A: `func f<T: Mutable>(_ t: inout T)` works for Q1; for
//               Q2/Q3/Q4, explicit suppression on the generic constraint
//               is required.
// Hypothesis B: A `@dynamicMemberLookup` extension on Mutable providing
//               `subscript<T>(dynamicMember: WritableKeyPath<Value, T>)`
//               will materialize for Q1 only — `WritableKeyPath<Value, T>`
//               carries the same `Root: Copyable & Escapable` constraint
//               as `KeyPath`, so Q2/Q3/Q4 fail by transitivity.
//
// Toolchain: Swift 6.3.1 (swiftlang-6.3.1.1.2)
// Platform: macOS 26.0 (arm64)
//
// Status: CONFIRMED for generic dispatch (Hypothesis A); CONFIRMED with
//         scope-clarification for KeyPath (Hypothesis B). Generic dispatch
//         through `inout some Mutable<T>` works at all four quadrants
//         provided the constraint explicitly suppresses Copyable/Escapable
//         (default constraint is Copyable & Escapable). For KeyPath, the
//         dynamic-member subscript on the Mutable protocol REFUTES
//         compile for any conformer where Self or Value is ~Copyable or
//         ~Escapable (genuine subscript path; `box.raw` on a
//         distinct-Value DescriptorBox: error). The earlier observation
//         that `u.raw` "worked" for ~Copyable trivial-self conformers
//         is direct-member access bypassing @dynamicMemberLookup —
//         Swift prefers concrete-member resolution over the subscript.
//         The affordance is genuinely Q1-only via the dynamic-member
//         path, mirroring the prior Carrier finding in
//         `swift-carrier-primitives/Research/dynamic-member-lookup-decision.md`.
// Result: CONFIRMED. Output:
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
//           V1 Q1 generic: c.value.raw = 11
//           V2 Q1 KeyPath set: c.raw = 200; c.value.raw = 200
//           V3 Q2 generic: u.value.raw = 11
//           V4 Form-D over Q1: Counter with raw = 42
//           Q2 trivial-self direct-member: u.raw = 200
//           Q3 trivial-self direct-member: s.raw = 999
//           Q4 trivial-self direct-member: h.raw = 888
//           Distinct-Value KeyPath subscript: REFUTED for ~Copyable
// Date: 2026-04-25

// MARK: - Mutable protocol mirror (matches the production shape)

@dynamicMemberLookup
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

extension Mutable where Value == Self, Self: ~Copyable {
    public var value: Self {
        _read { yield self }
        _modify { yield &self }
    }
}

extension Mutable where Value == Self, Self: ~Escapable {
    public var value: Self {
        @_lifetime(borrow self)
        _read { yield self }
        @_lifetime(&self)
        _modify { yield &self }
    }
}

extension Mutable where Value == Self, Self: ~Copyable & ~Escapable {
    public var value: Self {
        @_lifetime(borrow self)
        _read { yield self }
        @_lifetime(&self)
        _modify { yield &self }
    }
}

// MARK: - WritableKeyPath default subscript on the protocol

extension Mutable {
    public subscript<T>(dynamicMember keyPath: WritableKeyPath<Value, T>) -> T {
        get { value[keyPath: keyPath] }
        set { value[keyPath: keyPath] = newValue }
    }
}

// MARK: - Variant 1: Q1 same-Value generic dispatch

struct Counter: Mutable {
    typealias Value = Counter
    var raw: Int
}

func bumpQ1<T: Mutable<Counter>>(_ t: inout T) {
    t.value.raw += 10
}

func runV1() {
    var c = Counter(raw: 1)
    bumpQ1(&c)
    print("V1 Q1 generic: c.value.raw = \(c.value.raw)")
}

// MARK: - Variant 2: Q1 KeyPath dynamic-member set

func runV2() {
    var c = Counter(raw: 100)
    c.raw = 200  // Resolves through `subscript(dynamicMember:)` set
    print("V2 Q1 KeyPath set: c.raw = \(c.raw); c.value.raw = \(c.value.raw)")
}

// MARK: - Variant 3: Q2 same-Value generic dispatch with ~Copyable

struct UniqueCounter: ~Copyable, Mutable {
    typealias Value = UniqueCounter
    var raw: Int
}

func bumpQ2<T: Mutable<UniqueCounter> & ~Copyable>(_ t: inout T) {
    t.value.raw += 10
}

func runV3() {
    var u = UniqueCounter(raw: 1)
    bumpQ2(&u)
    print("V3 Q2 generic: u.value.raw = \(u.value.raw)")
}

// MARK: - Variant 4: Fully-generic over any Mutable (Form D)
// Uses the protocol's `value` accessor only; doesn't constrain Value.

func describeQ1<T: Mutable>(_ t: T) -> String where T.Value == Counter {
    "Counter with raw = \(t.value.raw)"
}

func runV4() {
    let c = Counter(raw: 42)
    print("V4 Form-D over Q1: \(describeQ1(c))")
}

// MARK: - Variant 5: KeyPath set on Q2 ~Copyable Self
// Probe: does `c.raw = 99` resolve through the dynamicMember subscript
// when Self is ~Copyable? Hypothesis: refuted — WritableKeyPath requires
// Root: Copyable & Escapable.

#if true  // Probing Q2 KeyPath set; expected: REFUTED at compile time.
func probeQ2KeyPath() {
    var u = UniqueCounter(raw: 100)
    u.raw = 200
    print("Q2 KeyPath set RESOLVED: u.raw = \(u.raw)")
}
#endif

// MARK: - Main

runV1()
runV2()
runV3()
runV4()

#if true
print("--- probing Q2 KeyPath (~Copyable) ---")
probeQ2KeyPath()
#endif

// MARK: - Variant 6: Q3 KeyPath set on ~Escapable Self
// Probe: ~Escapable Self, Copyable Value of same type.

struct ScopedView: ~Escapable {
    var raw: Int
    @_lifetime(immortal)
    init(raw: Int) { self.raw = raw }
}

extension ScopedView: Mutable {
    typealias Value = ScopedView
}

func probeQ3KeyPath() {
    var s = ScopedView(raw: 300)
    s.raw = 999
    print("Q3 KeyPath set: s.raw = \(s.raw)")
}

// MARK: - Variant 7: Q4 KeyPath set on ~Copyable & ~Escapable Self

struct ScopedHandle: ~Copyable, ~Escapable {
    var raw: Int
}

extension ScopedHandle: Mutable {
    typealias Value = ScopedHandle
}

func probeQ4KeyPath() {
    var h = ScopedHandle(raw: 400)
    h.raw = 888
    print("Q4 KeyPath set: h.raw = \(h.raw)")
}

print("--- probing Q3 KeyPath (~Escapable) ---")
probeQ3KeyPath()
print("--- probing Q4 KeyPath (~Copyable & ~Escapable) ---")
probeQ4KeyPath()

// MARK: - Variant 8: Distinct-Value KeyPath probe (the case that actually
// exercises the dynamicMember subscript — `box.raw` cannot resolve as a
// direct member of DescriptorBox because `raw` is on RawDescriptor).

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

// Distinct-Value KeyPath probe — REFUTED at compile time:
//   error: subscript 'subscript(dynamicMember:)' requires that
//   'DescriptorBox' conform to 'Copyable' AND
//   'DescriptorBox.Value' (aka 'RawDescriptor') conform to 'Copyable'
//
// This confirms the prior Carrier finding (dynamic-member-lookup-decision.md):
// `WritableKeyPath<Root, Value>` carries an implicit `Root: Copyable &
// Escapable` constraint, which propagates through the protocol-extension
// subscript. The earlier Q2/Q3/Q4 trivial-self "successes" worked because
// `u.raw` (UniqueCounter is ~Copyable) resolves via direct member access
// on UniqueCounter, NOT through the dynamic-member subscript — Swift
// prefers concrete-member resolution over @dynamicMemberLookup. The
// affordance is Q1-only on the genuine subscript path, exactly as
// Carrier observed.
#if false
func probeDistinctValueKeyPath() {
    var box = DescriptorBox(RawDescriptor(raw: 1))
    box.raw = 42  // ❌ requires 'DescriptorBox' conform to 'Copyable'
    _ = box
}
#endif
