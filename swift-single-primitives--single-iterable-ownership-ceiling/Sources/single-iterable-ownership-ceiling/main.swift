// MARK: - Single: Iterable ownership ceiling
//
// Purpose: Determine the widest ownership bound under which `Single` (a one-element container)
//          can vend an owned single-shot iterator (`Once`-shaped) through an `Iterable`-shaped
//          protocol, and what shape that protocol's iterator associatedtype must have.
//
// Hypothesis: `Single: Iterable where Element: Copyable` (vending a ~Copyable `Once`) is the
//             ceiling — BUT only if the protocol's iterator associatedtype permits a ~Copyable
//             iterator. An `associatedtype Iterator: <IteratorProtocol>` declared WITHOUT a
//             `~Copyable` suppression silently requires a *Copyable* iterator and so rejects the
//             ~Copyable `Once`. The real ceiling is the protocol's associatedtype shape, not the
//             element's copyability.
//
// Toolchain: Apple Swift 6.3.2 (swiftlang-6.3.2.1.108 clang-2100.1.1.101)
// Platform: arm64-apple-macosx26.0
//
// Result: CONFIRMED. The ceiling is set by the `Iterable` protocol's shape, not the element bound.
//   - V1 (associatedtype Iterator: MiniIterator, no ~Copyable suppression): REFUTED — `Single`
//     cannot vend the ~Copyable `MiniOnce`: "candidate would match ... if 'MiniOnce<Element>'
//     conformed to 'Copyable'".
//   - V2 (associatedtype Iterator: MiniIterator, ~Copyable, ~Escapable; makeIterator annotated
//     @_lifetime(borrow self); conformance `where Element: Copyable`): CONFIRMED — compiles and
//     runs (yields 42 then nil; container stays multipass).
//
//   So to let ANY type vend `Once`/`Empty` through it, the real `Iterable`
//   (swift-iterator-primitives) must BOTH (1) suppress Copyable & Escapable on its `Iterator`
//   associatedtype, and (2) annotate `makeIterator()` with `@_lifetime(borrow self)` (forced by
//   (1), since `Once` is unconditionally ~Escapable). The element bound for `Single`'s conformance
//   is then just `Copyable`.
//
//   Lifetime contract — why `borrow self`, not `copy self`: `Single` is `Escapable` when its
//   element is (conditional conformance), and `copy self` is rejected for an Escapable `self`
//   ("cannot copy the lifetime of an Escapable type"). `borrow self` is the only contract that
//   holds for both escapable and non-escapable containers — the vended iterator borrows the
//   container and may not outlive it. (An earlier revision used `copy self`, valid only because
//   `Single` was then unconditionally ~Escapable; once `Single` gained conditional Escapable, only
//   `borrow self` worked. That conditional-conformance gap on `Single` was fixed in the same arc.)
// Date: 2026-05-25

import Single_Primitives

// Minimal replica of the real `Iterator.`Protocol`` (swift-iterator-primitives): the foundational
// iterator is ~Copyable & ~Escapable and yields ~Copyable & ~Escapable elements.
protocol MiniIterator<Element>: ~Copyable, ~Escapable {
    associatedtype Element: ~Copyable & ~Escapable
    @_lifetime(&self)
    mutating func next() -> Element?
}

// Minimal replica of `Once`: owns one element, yields it once, then is exhausted.
// ~Copyable & ~Escapable, exactly like the real `Once`.
enum MiniOnce<Element: ~Copyable & ~Escapable>: MiniIterator, ~Copyable, ~Escapable {
    case pending(Element)
    case done

    @_lifetime(copy element)
    init(_ element: consuming Element) { self = .pending(element) }

    @_lifetime(&self)
    mutating func next() -> Element? {
        switch consume self {
        case .pending(let element):
            self = .done
            return element
        case .done:
            self = .done
            return nil
        }
    }
}

// MARK: - V1 — REFUTED: associatedtype without ~Copyable requires a Copyable iterator
//
// Replica of `Iterable` as it is currently shaped in swift-iterator-primitives:
// `associatedtype Iterator: MiniIterator` with NO `~Copyable` suppression.
protocol MiniIterableBroken: ~Copyable, ~Escapable {
    associatedtype Iterator: MiniIterator
    borrowing func makeIterator() -> Iterator
}

// Attempting to vend the ~Copyable `MiniOnce` does NOT compile. Captured diagnostic
// (swift 6.3.2), identical to the real `Single: Iterable` attempt against the real `Iterable`:
//
//   error: type 'Single<Element>' does not conform to protocol 'MiniIterableBroken'
//     note: candidate would match and infer 'Iterator' = 'MiniOnce<Element>'
//           if 'MiniOnce<Element>' conformed to 'Copyable'
//   error: cannot infer the lifetime dependence scope on a method with a ~Escapable parameter,
//          specify '@_lifetime(borrow self)' or '@_lifetime(copy self)'
//
// extension Single: MiniIterableBroken where Element: Copyable {
//     borrowing func makeIterator() -> MiniOnce<Element> {
//         MiniOnce(element)
//     }
// }

// MARK: - V2 — CONFIRMED: suppress the iterator associatedtype AND annotate makeIterator's lifetime
//
// Two changes are needed, both on the PROTOCOL — neither is the element bound:
//   1. `associatedtype Iterator: MiniIterator, ~Copyable, ~Escapable` — the iterator associatedtype
//      must permit a ~Copyable & ~Escapable iterator, mirroring the real `Iterator.`Protocol``.
//      Without this the ~Copyable `MiniOnce` is rejected (V1).
//   2. `@_lifetime(borrow self)` on `makeIterator()` — because `MiniOnce` is *unconditionally*
//      ~Escapable (even `MiniOnce<Int>`; `Once` is declared `~Escapable` with no conditional
//      Escapable conformance), `makeIterator()` returns a ~Escapable value whose lifetime scope the
//      compiler cannot infer. `borrow self` ties the vended iterator to a borrow of the container.
//      `copy self` is *rejected* here because `Single<Element>` is `Escapable` when `Element` is
//      ("cannot copy the lifetime of an Escapable type"); `borrow self` is the only contract that
//      works for both escapable and non-escapable containers. This is forced by change 1.
//
// The element bound is only `Copyable`: `makeIterator()` *borrows* the container, so the element
// must be copied into the owned iterator (a move-only element cannot be reached out of a borrow).
// `Element: Escapable` is NOT required — the iterator's lifetime is carried by the annotation.
protocol MiniIterableFixed: ~Copyable, ~Escapable {
    associatedtype Iterator: MiniIterator, ~Copyable, ~Escapable
    @_lifetime(borrow self)
    borrowing func makeIterator() -> Iterator
}

extension Single: MiniIterableFixed where Element: Copyable {
    @_lifetime(borrow self)
    borrowing func makeIterator() -> MiniOnce<Element> {
        MiniOnce(element)
    }
}

// Runtime confirmation: the vended iterator yields the element once then nil, and the container is
// only borrowed (so it stays multipass — a fresh iterator still yields). The exercise lives in a
// function scope: the vended `MiniOnce` borrows `single` (via `@_lifetime(borrow self)`), so it is
// scope-bound and cannot bind to a top-level `var` (which would escape to global scope) — a
// main.swift artifact, not a property of the conformance.
func exercise() {
    let single = Single(42)
    var first = single.makeIterator()
    precondition(first.next() == 42)
    precondition(first.next() == nil)
    var second = single.makeIterator()
    precondition(second.next() == 42)
    print("V2 CONFIRMED: Single<Int> vends MiniOnce yielding 42 then nil; container stays multipass")
}
exercise()
