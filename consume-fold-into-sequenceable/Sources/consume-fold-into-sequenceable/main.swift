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

/// THE SMALL ADD — an owned-consuming `forEach` terminal on `Sequenceable` for
/// `~Copyable` elements (Sequenceable's existing `forEach` is Copyable-gated).
/// This is the `Sequence.Consume.View.forEach(consuming:)` equivalent.
extension Sequenceable where Self: ~Copyable, Element: Escapable, Iterator.Failure == Never {
    consuming func forEachConsuming(_ body: (consuming Element) -> Void) {
        var iterator = makeIterator()
        while let element = iterator.next() {
            body(element)
        }
    }
}

// --- Exercises ---

func fullDrain() {
    print("[ii/iv] Full drain via forEachConsuming:")
    let source = Source([10, 20, 30])
    var sum = 0
    source.forEachConsuming { token in
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
