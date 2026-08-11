// MARK: - Relax trivial-self default extension across quadrants
//
// Purpose: Determine whether sibling default extensions on `Carrier`
//          (each with its own constraint suppression) can cover the
//          ~Escapable, ~Copyable, and ~Copyable & ~Escapable trivial-
//          self quadrants — collapsing per-conformer explicit witnesses
//          to one-liners.
// Hypothesis: Three sibling extensions (~Escapable / ~Copyable / both)
//             with quadrant-appropriate `@_lifetime` annotations cover
//             Q3, Q2, Q4 respectively. The existing Q1 default remains.
//
// Toolchain: Swift 6.3.1 (swiftlang-6.3.1.1.2)
// Platform: macOS 26.0 (arm64)
//
// Status: CONFIRMED — all three sibling default extensions provide
//         working witnesses for their target quadrants.
// Result: CONFIRMED. Output:
//           V1 Q3: span.underlying.count = 3
//           V2 Q2: v.underlying.raw = 7
//           V3 Q4: v.underlying.raw = 11
//         Three sibling default extensions cover Q2, Q3, Q4 respectively;
//         the existing Q1 default remains. The ~Escapable / ~Copyable
//         suppressions on the where clause propagate the constraint
//         relaxation, admitting witness candidates for the corresponding
//         quadrant. `@_lifetime` annotations are valid in the
//         ~Escapable variants (Q3, Q4) because the Self/Underlying
//         result type is now ~Escapable; they remain absent from Q1
//         and Q2 (where Self is Escapable and lifetime annotations on
//         Escapable results are rejected).
// Date: 2026-04-25

// MARK: - Carrier mirror

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

// MARK: - Sibling default extensions, per quadrant

// Q1 — Copyable & Escapable Self (existing production default).
extension Carrier where Underlying == Self {
    public var underlying: Self {
        _read { yield self }
    }
    public init(_ underlying: consuming Self) {
        self = underlying
    }
}

// Q3 — Copyable, ~Escapable Self.
extension Carrier where Underlying == Self, Self: ~Escapable {
    public var underlying: Self {
        @_lifetime(borrow self)
        _read { yield self }
    }
    @_lifetime(copy underlying)
    public init(_ underlying: consuming Self) {
        self = underlying
    }
}

// Q2 — ~Copyable, Escapable Self.
extension Carrier where Underlying == Self, Self: ~Copyable {
    public var underlying: Self {
        _read { yield self }
    }
    public init(_ underlying: consuming Self) {
        self = underlying
    }
}

// Q4 — ~Copyable & ~Escapable Self.
extension Carrier where Underlying == Self, Self: ~Copyable & ~Escapable {
    public var underlying: Self {
        @_lifetime(borrow self)
        _read { yield self }
    }
    @_lifetime(copy underlying)
    public init(_ underlying: consuming Self) {
        self = underlying
    }
}

// MARK: - Variant 1: Q3 conformer (Copyable, ~Escapable Self) via Span
// Hypothesis: Span: Carrier { typealias Underlying = Span<Element> } now
// satisfies the protocol via the Q3 sibling default — no explicit witnesses.
// Result: CONFIRMED — span.underlying.count round-trips through the
//         Q3 default extension; no per-Span explicit witnesses required.

extension Span: Carrier {
    public typealias Underlying = Span<Element>
}

func runV1() {
    let bytes: [UInt8] = [10, 20, 30]
    unsafe bytes.withUnsafeBufferPointer { buffer in
        let span = unsafe Span<UInt8>(_unsafeElements: buffer)
        // If the Q3 default applies, span.underlying.count works without
        // the conformance shipping its own witnesses.
        print("V1 Q3: span.underlying.count = \(span.underlying.count)")
    }
}

// MARK: - Variant 2: Q2 conformer (~Copyable, Escapable Self)
// Hypothesis: a synthetic ~Copyable struct conforms via the Q2 sibling
// default with no explicit witnesses.
// Result: CONFIRMED — UniqueValue conforms with one-line typealias.

struct UniqueValue: ~Copyable, Carrier {
    typealias Underlying = UniqueValue
    var raw: Int
}

func runV2() {
    let v = UniqueValue(raw: 7)
    let raw = v.underlying.raw
    print("V2 Q2: v.underlying.raw = \(raw)")
}

// MARK: - Variant 3: Q4 conformer (~Copyable & ~Escapable Self)
// Hypothesis: a synthetic ~Copyable & ~Escapable struct conforms via the
// Q4 sibling default with no explicit witnesses.
// Result: CONFIRMED — ScopedValue conforms with one-line typealias.
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES

struct ScopedValue: ~Copyable, ~Escapable, Carrier {
    typealias Underlying = ScopedValue
    var raw: Int
}

func runV3() {
    let v = ScopedValue(raw: 11)
    let raw = v.underlying.raw
    print("V3 Q4: v.underlying.raw = \(raw)")
}

// MARK: - Main

runV1()
print("V1 complete")
runV2()
print("V2 complete")
runV3()
print("V3 complete")
