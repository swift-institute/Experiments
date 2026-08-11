// MARK: - Property.View + Consuming makeIterator() Experiment (Round 2)
// Purpose: Find a pattern that preserves `& ~Copyable` on Property.View
//          extensions while working with consuming makeIterator
//
// Round 1 findings:
//   - TEST 1: Copyable implicit (no ~Copyable) + pointee → CONFIRMED
//   - TEST 1b: ~Copyable + pointee → REFUTED (can't consume borrow)
//   - TEST 3: _borrowedMakeIterator → REFUTED (escapes borrow scope)
//   - TEST 4: withIterator closure → CONFIRMED (Copyable only)
//
// Round 2 hypothesis: A borrowing `forEach` protocol requirement/extension
//   lets Property.View call borrowing method on pointee without consuming.
//   ~Copyable types implement it via internal traversal.
//   Copyable types get default via copy + makeIterator.
//
// Toolchain: Swift 6.2
// Platform: macOS (arm64)
//
// Result: CONFIRMED — TEST A (forEach requirement) and TEST E (Clearable move+reinit)
// Revalidated: Swift 6.3.1 (2026-04-30) — STILL PRESENT
//         both compile and run. TEST 1b REFUTED (can't consume through borrowed pointee).
//         Decision: Dual-protocol (Option C) — see Research/consuming-vs-borrowing-iteration.md
// Date: 2026-02-26

// ===----------------------------------------------------------------------===//
// SHARED INFRASTRUCTURE
// ===----------------------------------------------------------------------===//

protocol IterP: ~Copyable, ~Escapable {
    associatedtype Element: ~Copyable
    @_lifetime(self: immortal)
    mutating func next() -> Element?
}

protocol SeqP: ~Copyable, ~Escapable {
    associatedtype Element: ~Copyable
    associatedtype Iterator: IterP & ~Copyable & ~Escapable where Iterator.Element == Element
    @_lifetime(copy self)
    consuming func makeIterator() -> Iterator
}

// Copyable conformer
struct CopyableSeq: SeqP {
    var data: [Int]
    struct Iter: IterP {
        var inner: Array<Int>.Iterator
        @_lifetime(self: immortal)
        mutating func next() -> Int? { inner.next() }
    }
    consuming func makeIterator() -> Iter {
        Iter(inner: data.makeIterator())
    }
}

// ~Copyable conformer with internal index-based traversal
struct MoveOnlySeq: ~Copyable, SeqP {
    var data: [Int]
    struct Iter: IterP {
        var inner: Array<Int>.Iterator
        @_lifetime(self: immortal)
        mutating func next() -> Int? { inner.next() }
    }
    consuming func makeIterator() -> Iter {
        Iter(inner: data.makeIterator())
    }
}

// Minimal Property.View
@safe
struct PView<Base: ~Copyable>: ~Copyable, ~Escapable {
    let base: UnsafeMutablePointer<Base>

    @_lifetime(borrow base)
    init(_ base: UnsafeMutablePointer<Base>) {
        unsafe self.base = base
    }
}

print("Infrastructure: OK")

// ===----------------------------------------------------------------------===//
// TEST A: Borrowing forEach as protocol REQUIREMENT
// Hypothesis: Protocol requires `borrowing func forEach(...)`.
//             Copyable types get default via copy + makeIterator.
//             ~Copyable types implement via internal traversal.
//             PView extension with ~Copyable calls borrowing forEach on pointee.
// ===----------------------------------------------------------------------===//

// MARK: - TEST A: Protocol requirement approach

protocol SeqPv2: ~Copyable, ~Escapable {
    associatedtype Element: ~Copyable
    associatedtype Iterator: IterP & ~Copyable & ~Escapable where Iterator.Element == Element
    @_lifetime(copy self)
    consuming func makeIterator() -> Iterator

    // NEW: borrowing forEach — enables iteration without consuming
    borrowing func forEach(_ body: (borrowing Element) -> Void)
}

// Default for Copyable: copy self, consume copy into iterator
extension SeqPv2 where Self: Copyable {
    borrowing func forEach(_ body: (borrowing Element) -> Void) {
        var iter = (copy self).makeIterator()
        while let element = iter.next() {
            body(element)
        }
    }
}

// Copyable conformer — gets default forEach
struct CopyableSeqA: SeqPv2 {
    var data: [Int]
    struct Iter: IterP {
        var inner: Array<Int>.Iterator
        @_lifetime(self: immortal)
        mutating func next() -> Int? { inner.next() }
    }
    consuming func makeIterator() -> Iter {
        Iter(inner: data.makeIterator())
    }
    // forEach: uses default (copy self)
}

// ~Copyable conformer — must implement forEach manually
struct MoveOnlySeqA: ~Copyable, SeqPv2 {
    var data: [Int]
    struct Iter: IterP {
        var inner: Array<Int>.Iterator
        @_lifetime(self: immortal)
        mutating func next() -> Int? { inner.next() }
    }
    consuming func makeIterator() -> Iter {
        Iter(inner: data.makeIterator())
    }

    // ~Copyable must provide its own borrowing forEach
    borrowing func forEach(_ body: (borrowing Element) -> Void) {
        for i in 0..<data.count {
            body(data[i])
        }
    }
}

// PView extension with ~Copyable — calls borrowing forEach on pointee
extension PView where Base: SeqPv2 & ~Copyable {
    func testAForEach(_ body: (borrowing Base.Element) -> Void) {
        unsafe base.pointee.forEach(body)
    }
}

func testACopyable() {
    var s = CopyableSeqA(data: [1, 2, 3])
    let view = unsafe PView<CopyableSeqA>(&s)
    var sum = 0
    view.testAForEach { sum += $0 }
    let survived = s.data.count == 3
    print("TEST A (Copyable, protocol forEach): sum=\(sum), survived=\(survived)")
}

func testAMoveOnly() {
    var s = MoveOnlySeqA(data: [10, 20, 30])
    let view = unsafe PView<MoveOnlySeqA>(&s)
    var sum = 0
    view.testAForEach { sum += $0 }
    let survived = s.data.count == 3
    print("TEST A (~Copyable, manual forEach): sum=\(sum), survived=\(survived)")
}

// ===----------------------------------------------------------------------===//
// TEST B: Borrowing forEach as protocol EXTENSION only (not requirement)
// Hypothesis: Protocol extension with ~Copyable & ~Escapable provides forEach.
//             PView extension with ~Copyable calls it.
//             For ~Copyable types, this extension is NOT available unless
//             they also happen to be Copyable (default only works for Copyable).
// ===----------------------------------------------------------------------===//

// MARK: - TEST B: Protocol extension only (not requirement)

// Default forEach for Copyable conformers of SeqP
extension SeqP where Self: Copyable {
    borrowing func _forEach(_ body: (borrowing Element) -> Void) {
        var iter = (copy self).makeIterator()
        while let element = iter.next() {
            body(element)
        }
    }
}

// PView extension: ~Copyable but calls _forEach (which requires Copyable)
// This should FAIL because _forEach isn't available for ~Copyable Base
// extension PView where Base: SeqP & ~Copyable {
//     func testBForEach(_ body: (borrowing Base.Element) -> Void) {
//         unsafe base.pointee._forEach(body)
//     }
// }
// ^ Expected: error — _forEach requires Copyable

// PView extension WITHOUT ~Copyable: _forEach works
extension PView where Base: SeqP {
    func testBForEach(_ body: (borrowing Base.Element) -> Void) {
        unsafe base.pointee._forEach(body)
    }
}

func testBCopyable() {
    var s = CopyableSeq(data: [1, 2, 3])
    let view = unsafe PView<CopyableSeq>(&s)
    var sum = 0
    view.testBForEach { sum += $0 }
    let survived = s.data.count == 3
    print("TEST B (Copyable, protocol ext forEach): sum=\(sum), survived=\(survived)")
}

// ===----------------------------------------------------------------------===//
// TEST C: withIterator on pointee in ~Copyable extension
// Hypothesis: withIterator closure pattern called on Copyable-constrained
//             protocol extension, from a ~Copyable PView extension
// ===----------------------------------------------------------------------===//

// MARK: - TEST C: withIterator from ~Copyable extension

extension SeqP where Self: Copyable {
    borrowing func withIterator<R>(_ body: (inout Iterator) -> R) -> R {
        var iter = (copy self).makeIterator()
        return body(&iter)
    }
}

// Should FAIL: withIterator requires Copyable, extension has ~Copyable
// extension PView where Base: SeqP & ~Copyable {
//     func testCForEach(_ body: (borrowing Base.Element) -> Void) {
//         unsafe base.pointee.withIterator { iter in
//             while let element = iter.next() {
//                 body(element)
//             }
//         }
//     }
// }

// ===----------------------------------------------------------------------===//
// TEST D: forEach protocol requirement with default, ~Copyable override
// Hypothesis: Same as TEST A but test if Copyable types auto-satisfy
//             the requirement without explicit implementation
// ===----------------------------------------------------------------------===//

// MARK: - TEST D: Default satisfaction check
// (Already covered by TEST A — CopyableSeqA doesn't implement forEach,
//  gets default from Copyable extension. CONFIRMED if TEST A compiles.)

// ===----------------------------------------------------------------------===//
// TEST E: Using `consuming func forEach` + move/reinitialize for Clearable
// Hypothesis: For ~Copyable Clearable types, move out, iterate, reinitialize
//             with post-removeAll state. Need Clearable + empty init.
// ===----------------------------------------------------------------------===//

// MARK: - TEST E: Consuming forEach with reinitialize

protocol Clearable: ~Copyable {
    mutating func removeAll()
    init()  // empty state constructor
}

extension MoveOnlySeq: Clearable {
    mutating func removeAll() { data.removeAll() }
    init() { data = [] }
}

extension PView where Base: SeqP & ~Copyable & Clearable {
    @_lifetime(&self)
    mutating func testEForEachConsuming(_ body: (borrowing Base.Element) -> Void) {
        let owned = unsafe base.move()
        var iterator = owned.makeIterator()
        while let element = iterator.next() {
            body(element)
        }
        // Reinitialize with empty state
        unsafe base.initialize(to: Base())
    }
}

func testEMoveOnly() {
    var s = MoveOnlySeq(data: [10, 20, 30])
    var view = unsafe PView<MoveOnlySeq>(&s)
    var sum = 0
    view.testEForEachConsuming { sum += $0 }
    // s should now be reinitialized to empty
    let isEmpty = s.data.isEmpty
    print("TEST E (~Copyable consuming + reinit): sum=\(sum), isEmpty=\(isEmpty)")
}

// ===----------------------------------------------------------------------===//
// EXECUTION
// ===----------------------------------------------------------------------===//

testACopyable()
testAMoveOnly()
testBCopyable()
testEMoveOnly()

print()
print("===== RESULTS =====")
