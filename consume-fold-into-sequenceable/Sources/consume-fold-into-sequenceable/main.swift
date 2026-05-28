// Build-check: REAL `Sequenceable` subsumes `Sequence.Consume.View` for a
// ~Copyable-Element conformer.
//
// [CLAIM-ii]  owned ~Copyable yield: makeIterator() (consuming) → an owned ~Copyable
//             iterator whose next() MOVES OWNED ~Copyable elements out of OWNED storage
//             (NOT A4's borrowed move-out).
// [CLAIM-iii] early-exit cleanup: the ~Copyable iterator's deinit cleans up remaining
//             elements on early drop (≡ Sequence.Consume.View's State.deinit).
// [CLAIM-iv]  call-site: `x.consume().forEach{}` ≡ a `forEachConsuming` terminal;
//             `while let e = view.next()` ≡ `while let e = it.next()`.
// The owned-consuming forEach terminal is the "small ADD" to Sequenceable.

import Sequence_Protocol_Primitives
import Iterator_Primitive
import Iterator_Protocol
import Either_Primitives

/// A move-only (`~Copyable`), Escapable element — the resource-shaped case (file
/// descriptor / unique handle / token).
struct Token: ~Copyable {
    let id: Int
    init(_ id: Int) { self.id = id }
}

/// Owned `~Copyable` iterator over raw storage. `next()` MOVES elements out of
/// OWNED storage; `deinit` cleans up any remaining elements on early exit.
struct Drainer: ~Copyable {
    @usableFromInline var base: UnsafeMutablePointer<Token>
    @usableFromInline let count: Int
    @usableFromInline var index: Int

    init(base: UnsafeMutablePointer<Token>, count: Int) {
        unsafe self.base = base
        self.count = count
        self.index = 0
    }

    deinit {
        let remaining = count - index
        print("  Drainer.deinit: \(remaining) remaining element(s) cleaned up")
        var i = index
        while i < count {
            unsafe (base + i).deinitialize(count: 1)
            i += 1
        }
        unsafe base.deallocate()
    }
}

extension Drainer: Iterator.`Protocol` {
    typealias Element = Token
    typealias Failure = Never

    // Token is Escapable, so this yields an OWNED value — no @_lifetime (the
    // compiler rejects @_lifetime on an Escapable result; Sequenceable doc §"@_lifetime").
    mutating func next() -> Token? {
        guard index < count else { return nil }
        let token = unsafe (base + index).move()   // OWNED move-out of a ~Copyable
        index += 1
        return token
    }
}

/// A `~Copyable`-Element `Sequenceable` source. `makeIterator()` (consuming)
/// transfers storage ownership to the iterator — the consume()-equivalent.
struct Source: ~Copyable, Sequenceable {
    typealias Element = Token
    typealias Iterator = Drainer

    @usableFromInline var base: UnsafeMutablePointer<Token>
    @usableFromInline let count: Int

    init(_ ids: [Int]) {
        count = ids.count
        unsafe base = .allocate(capacity: ids.count)
        for (i, id) in ids.enumerated() {
            unsafe (base + i).initialize(to: Token(id))
        }
    }

    // Drainer is Escapable (owns, doesn't borrow) → omit @_lifetime.
    consuming func makeIterator() -> Drainer {
        Drainer(base: base, count: count)
    }
}

// THE PERFECTED "small ADD" — a CONSUMING `forEach` terminal on `Sequenceable`.
//
// Surface: a plain `consuming func forEach` (NOT a `Property.Inout` accessor, NOT a
// compound `forEachConsuming`). Mirrors `Iterable.forEach`'s method shape (typed-throws
// + a fallible `Either<E, Iterator.Failure>` overload), `consuming` instead of `borrowing`.
//
// WHY a method, not the `Collection.ForEach` Property accessor: `Collection.ForEach`'s
// accessor is INDEX-based (borrow-by-index + removeAll, never consuming self). A
// `Property.Inout` accessor cannot (a) consume self (it is an `&self` borrow view) nor
// (b) hold a `makeIterator()` iterator across a `while` loop on the production compiler
// (the `_read` coroutine is statement-scoped — documented at `Iterable+ForEach.swift`
// and `Collection.ForEach+Property.Inout.Iterable.swift`). Sequenceable has no indices
// and `makeIterator()` is consuming-self, so it mirrors `Iterable`'s func-method shape.
//
// `Element: Escapable` because this is an EXTRACTION terminal (like `collect`/`first`);
// `~Escapable` elements use the borrowing `forEach` on `Sequence.Borrowing.Protocol`.

extension Sequenceable where Self: ~Copyable, Element: Escapable, Iterator.Failure == Never {
    /// Consuming iteration terminal (infallible iterator). `consuming` → single-pass.
    consuming func forEach<E: Swift.Error>(
        _ body: (consuming Element) throws(E) -> Void
    ) throws(E) {
        var iterator = makeIterator()
        while let element = iterator.next() {
            try body(element)
        }
    }
}

extension Sequenceable where Self: ~Copyable, Element: Escapable {
    /// Consuming iteration terminal (fallible iterator) — fuses the closure error `E`
    /// and the iterator's `Failure` into `Either`, unerased ([API-ERR-001]).
    consuming func forEach<E: Swift.Error>(
        _ body: (consuming Element) throws(E) -> Void
    ) throws(Either<E, Iterator.Failure>) {
        var iterator = makeIterator()
        while true {
            let step: Element?
            do {
                step = try iterator.next()
            } catch {
                throw Either.right(error)
            }
            guard let element = step else { return }
            do {
                try body(element)
            } catch {
                throw Either.left(error)
            }
        }
    }
}

// --- Exercises ---

func fullDrain() {
    print("[ii/iv] Full drain via consuming forEach (typed-throws):")
    let source = Source([10, 20, 30])
    var sum = 0
    source.forEach { token in
        sum += token.id
    }
    print("  sum=\(sum)  (expect 60; expect Drainer.deinit: 0 remaining)")
}

func pullStyleWhileLet() {
    print("[iv] Pull-style via `while let it.next()`:")
    let source = Source([1, 2, 3, 4])
    var iterator = source.makeIterator()
    var seen: [Int] = []
    while let token = iterator.next() {
        seen.append(token.id)
    }
    print("  seen=\(seen)  (expect [1, 2, 3, 4]; expect Drainer.deinit: 0 remaining)")
}

func earlyExitCleanup() {
    print("[iii] Early-exit cleanup:")
    let source = Source([5, 6, 7, 8, 9])
    var iterator = source.makeIterator()
    _ = iterator.next()   // 5
    _ = iterator.next()   // 6
    print("  consumed 2 of 5; dropping iterator now (expect Drainer.deinit: 3 remaining)")
    // iterator drops here → deinit must clean up the remaining 3
}

fullDrain()
pullStyleWhileLet()
earlyExitCleanup()
print("DONE")
