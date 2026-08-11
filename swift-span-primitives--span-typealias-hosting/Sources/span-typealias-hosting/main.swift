// MARK: - Span Typealias + Capability-Protocol Hosting ("best of all worlds")
//
// Purpose:    Validate aliasing the package's top-level `Span` to `Swift.Span` AND
//             `Span.Mutable` to `Swift.MutableSpan`, while KEEPING the bare
//             `Span.Protocol` / `Span.Mutable.Protocol` / `Span.Raw` spellings —
//             exercised across a module boundary (the consumer view).
//
// Hypothesis: An UNBOUND `typealias Span = Swift.Span`, a member `typealias Mutable =
//             Swift.MutableSpan`, and hidden capabilities surfaced as Element-free
//             member typealiases give a consumer: `Span<E>` and `Span.Mutable<E>` as
//             the stdlib span types, plus bare `Span.Protocol` / `Span.Mutable.Protocol`
//             — no phantom element, no ecosystem rename.
//
// Toolchain:  Apple Swift 6.3.2 (swiftlang-6.3.2.1.108)
// Platform:   macOS 26 (arm64)
//
// Status:     CONFIRMED — cross-module, debug + release (Outputs/). A BOUND alias does
//             NOT preserve the bare spellings (Counterexamples/03).
// Result:     CONFIRMED — `swift run` prints the evidence block below.
// Date:       2026-06-23

import UnboundAlias

// `Span` / `Span.Mutable` here are UnboundAlias's aliases to Swift.Span / Swift.MutableSpan.

// MARK: Read side — bare Span.Protocol, no phantom element

struct View: ~Copyable, ~Escapable, Span.`Protocol` {
    let _s: Swift.Span<Int>
    @_lifetime(borrow s) init(_ s: borrowing Swift.Span<Int>) { _s = copy s }
    var span: Swift.Span<Int> { @_lifetime(borrow self) get { _s } }
}
func isEmpty<S: Span.`Protocol` & ~Copyable & ~Escapable>(_ s: borrowing S) -> Bool { s.span.isEmpty }

// MARK: Mutable side — Span.Mutable<E> is the stdlib mutable span; Span.Mutable.Protocol bare

/// `Span.Mutable<Int>` resolves to `Swift.MutableSpan<Int>`.
func bumpFirst(_ m: inout Span.Mutable<Int>) { m[0] += 100 }
/// Bare `Span.Mutable.Protocol` as a constraint (compile-level proof).
func requiresMutable<T: Span.Mutable.`Protocol` & ~Copyable>(_ t: borrowing T) {}

// MARK: Raw — bare Span.Raw as a type, cross-module
func rawCount(_ r: Span.Raw) -> Int { r.count }

// =============================================================================
// MARK: Evidence — run over real spans, cross-module
// =============================================================================

let readStorage: [Int] = [10, 20, 30]
readStorage.withUnsafeBufferPointer { buf in
    let span = Swift.Span(_unsafeElements: buf)
    print("Span<Int> is the stdlib read span; count =", span.count)               // 3
    print("bare Span.Protocol on linchpin Swift.Span; isEmpty =", isEmpty(span))  // false
    let v = View(span)
    print("bare Span.Protocol on cross-module conformer; isEmpty =", isEmpty(v))  // false
    print("bare Span.Raw cross-module; count =", rawCount(Span<Int>.Raw(count: 99)))  // 99
}

var writeStorage: [Int] = [1, 2, 3]
writeStorage.withUnsafeMutableBufferPointer { buf in
    var m: Span.Mutable<Int> = Swift.MutableSpan(_unsafeElements: buf)   // Span.Mutable<Int> == MutableSpan<Int>
    bumpFirst(&m)
}
print("Span.Mutable<Int> is the stdlib mutable span; mutated first =", writeStorage[0])  // 101
print("BEST OF ALL WORLDS: Span<E>, Span.Mutable<E>, Span.Protocol, Span.Mutable.Protocol, Span.Raw — all bare, cross-module")
