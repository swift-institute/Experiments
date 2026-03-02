// MARK: - Escapable Lazy Sequence Borrowing
// Purpose: Validate ~Escapable lazy operator types with borrowing/consuming patterns
//   V1: Can a ~Escapable struct use @_lifetime(borrow)?
//   V2: Can protocols suppress both Copyable and Escapable? Do Copyable types conform?
//   V3: Can a ~Escapable consuming lazy map iterate via protocol conformance?
//   V4: Do chained ~Escapable consuming operators compose (map → filter)?
//   V5: Does manual for-in desugaring work with inline ~Escapable temporaries?
//   V6: Can a @_lifetime(borrow self) extension method return a ~Escapable adapter?
//
// Toolchain: Apple Swift 6.2.3 (swiftlang-6.2.3.3.21)
// Platform: macOS 26.0 (arm64)
//
// Result: ALL CONFIRMED (9/9 variants)
//   V1: CONFIRMED — ~Escapable struct with @_lifetime(borrow) compiles and works
//   V2: CONFIRMED — protocol with ~Copyable & ~Escapable suppression, Copyable types conform
//   V3: CONFIRMED — ~Escapable consuming lazy map iterates via EscSequence conformance
//   V4: CONFIRMED — chained ~Escapable operators compose (EscFiltered<EscMapped<...>>)
//   V5: CONFIRMED — for-in desugaring works with inline ~Escapable temporaries
//   V6: CONFIRMED — @_lifetime(borrow self) extension returns scoped ~Escapable adapter
//   V7: CONFIRMED — ~Escapable iterator with @_lifetime(self: immortal) on next()
//   V8: CONFIRMED — ~Escapable lazy map with ~Escapable iterator
//   V9: CONFIRMED — chained full ~Escapable operators with ~Escapable iterators
//
// Key findings:
//   - CORRECT DESIGN: Both sequence AND iterator protocols suppress ~Escapable.
//     @_lifetime(self: immortal) on mutating func next() tells the compiler the
//     returned element doesn't borrow self — it's a pure state transition.
//     This matches Swift.Span.Iterator and Sequence.Iterator.Borrowing.Protocol.
//   - @_lifetime is the underscored attribute; @lifetime emits "use @_lifetime" warning
//   - Extensions conforming ~Escapable types need explicit `where Base: ~Copyable & ~Escapable`
//   - @_lifetime(copy base) works with consuming init; @_lifetime(borrow base) with borrowing init
//   - @_lifetime(copy self) on consuming func is valid for ~Escapable conformers but
//     INVALID for Escapable conformers ("invalid lifetime dependence on Escapable value").
//     Escapable conformers omit the annotation; protocol declares it for the ~Escapable case.
// Date: 2026-02-25

// ============================================================================
// MARK: - V1: Basic ~Escapable struct with @_lifetime(borrow)
// ============================================================================
// Hypothesis: ~Escapable + @_lifetime(borrow) compiles and works.

struct BorrowedView<T>: ~Escapable {
    let value: T

    @_lifetime(borrow source)
    init(source: borrowing T) {
        self.value = copy source
    }
}

func testV1() {
    let x = 42
    let view = BorrowedView(source: x)
    print("V1 value: \(view.value)")
    assert(view.value == 42, "V1 FAILED")
    print("V1: CONFIRMED — ~Escapable struct with @_lifetime(borrow)")
}

// ============================================================================
// MARK: - V2: Protocol with ~Copyable, ~Escapable suppression
// ============================================================================
// Hypothesis: A protocol can suppress both Copyable and Escapable.
//             Concrete Copyable+Escapable types (using Int) still conform.
//
// Design: The sequence protocol is ~Copyable, ~Escapable.
//         The iterator protocol is ~Copyable only — iterators own their state
//         and don't need lifetime scoping. This avoids the requirement for
//         @_lifetime annotations on mutating func next().

protocol EscSequence: ~Copyable, ~Escapable {
    associatedtype Element
    associatedtype Iterator: EscIterator where Iterator.Element == Element
    consuming func makeIterator() -> Iterator
}

protocol EscIterator: ~Copyable {
    associatedtype Element
    mutating func next() -> Element?
}

// Concrete source — Copyable + Escapable, should still conform
struct IntSource: EscSequence {
    let values: [Int]

    struct Iterator: EscIterator {
        var index: Int = 0
        let values: [Int]
        mutating func next() -> Int? {
            guard index < values.count else { return nil }
            defer { index += 1 }
            return values[index]
        }
    }

    consuming func makeIterator() -> Iterator {
        Iterator(values: values)
    }
}

func testV2() {
    let source = IntSource(values: [10, 20, 30])
    var iter = source.makeIterator()
    var results: [Int] = []
    while let e = iter.next() {
        results.append(e)
    }
    print("V2 results: \(results)")
    assert(results == [10, 20, 30], "V2 FAILED")
    print("V2: CONFIRMED — protocol with ~Copyable & ~Escapable, concrete type conforms")
}

// ============================================================================
// MARK: - V3: ~Escapable consuming lazy map with iteration
// ============================================================================
// Hypothesis: A ~Escapable lazy map that consumes its base can iterate
//             via protocol conformance to EscSequence.

struct EscMapped<Base: EscSequence & ~Copyable & ~Escapable, Input, Output>: ~Copyable, ~Escapable
    where Base.Element == Input
{
    let base: Base
    let transform: (Input) -> Output

    @_lifetime(copy base)
    init(base: consuming Base, transform: @escaping (Input) -> Output) {
        self.base = base
        self.transform = transform
    }
}

extension EscMapped: EscSequence where Base: ~Copyable & ~Escapable {
    typealias Element = Output

    struct Iter: EscIterator {
        var base: Base.Iterator
        let transform: (Input) -> Output

        mutating func next() -> Output? {
            guard let e = base.next() else { return nil }
            return transform(e)
        }
    }

    consuming func makeIterator() -> Iter {
        Iter(base: base.makeIterator(), transform: transform)
    }
}

func testV3() {
    let source = IntSource(values: [1, 2, 3, 4, 5])
    let mapped = EscMapped(base: source, transform: { $0 * 10 })

    print("V3 type: \(type(of: mapped))")

    var results: [Int] = []
    var iter = mapped.makeIterator()
    while let e = iter.next() {
        results.append(e)
    }
    print("V3 results: \(results)")
    assert(results == [10, 20, 30, 40, 50], "V3 FAILED")
    print("V3: CONFIRMED — ~Escapable consuming lazy map iterates correctly")
}

// ============================================================================
// MARK: - V4: Chained ~Escapable operators (map → filter)
// ============================================================================
// Hypothesis: ~Escapable lazy operators compose when the inner is consumed
//             by the outer (consuming chain with ~Escapable at each level).

struct EscFiltered<Base: EscSequence & ~Copyable & ~Escapable, ElementType>: ~Copyable, ~Escapable
    where Base.Element == ElementType
{
    let base: Base
    let predicate: (ElementType) -> Bool

    @_lifetime(copy base)
    init(base: consuming Base, predicate: @escaping (ElementType) -> Bool) {
        self.base = base
        self.predicate = predicate
    }
}

extension EscFiltered: EscSequence where Base: ~Copyable & ~Escapable {
    typealias Element = ElementType

    struct Iter: EscIterator {
        var base: Base.Iterator
        let predicate: (ElementType) -> Bool

        mutating func next() -> ElementType? {
            while let e = base.next() {
                if predicate(e) { return e }
            }
            return nil
        }
    }

    consuming func makeIterator() -> Iter {
        Iter(base: base.makeIterator(), predicate: predicate)
    }
}

func testV4() {
    let source = IntSource(values: [1, 2, 3, 4, 5])
    let mapped = EscMapped(base: source, transform: { $0 * 10 })
    let filtered = EscFiltered(base: mapped, predicate: { $0 > 20 })

    print("V4 type: \(type(of: filtered))")

    var results: [Int] = []
    var iter = filtered.makeIterator()
    while let e = iter.next() {
        results.append(e)
    }
    print("V4 results: \(results)")
    assert(results == [30, 40, 50], "V4 FAILED")
    print("V4: CONFIRMED — chained ~Escapable operators compose")
}

// ============================================================================
// MARK: - V5: for-in desugaring with inline ~Escapable temporary
// ============================================================================
// Hypothesis: Creating a ~Escapable pipeline inline and immediately
//             calling consuming makeIterator() works — the temporary
//             is consumed before it would need to escape.

func testV5() {
    var results: [Int] = []
    // Inline construction → immediate consuming makeIterator()
    var iter = EscMapped(
        base: IntSource(values: [1, 2, 3]),
        transform: { $0 * 100 }
    ).makeIterator()

    while let e = iter.next() {
        results.append(e)
    }

    print("V5 results: \(results)")
    assert(results == [100, 200, 300], "V5 FAILED")
    print("V5: CONFIRMED — for-in desugaring works with inline ~Escapable temporaries")
}

// ============================================================================
// MARK: - V6: @_lifetime(borrow self) extension method returning ~Escapable
// ============================================================================
// Hypothesis: An extension method can return a ~Escapable adapter
//             scoped to the borrowing lifetime of self. The adapter
//             copies the Copyable base internally but is lifetime-bounded
//             externally via @_lifetime(borrow).

struct BorrowedMapped<Base: EscSequence & Copyable & Escapable, Output>: ~Escapable {
    let base: Base
    let transform: (Base.Element) -> Output

    @_lifetime(borrow base)
    init(base: borrowing Base, transform: @escaping (Base.Element) -> Output) {
        self.base = copy base
        self.transform = transform
    }

    consuming func collect() -> [Output] {
        var results: [Output] = []
        var iter = base.makeIterator()
        while let e = iter.next() {
            results.append(transform(e))
        }
        return results
    }
}

extension IntSource {
    @_lifetime(borrow self)
    borrowing func lazyMap<Output>(_ transform: @escaping (Int) -> Output) -> BorrowedMapped<Self, Output> {
        BorrowedMapped(base: self, transform: transform)
    }
}

func testV6() {
    let source = IntSource(values: [1, 2, 3])
    let mapped = source.lazyMap { $0 * 5 }

    let results = mapped.collect()
    print("V6 results: \(results)")
    assert(results == [5, 10, 15], "V6 FAILED")
    print("V6: CONFIRMED — @_lifetime(borrow self) extension returns ~Escapable adapter")
}

// ============================================================================
// MARK: - V7: ~Escapable iterator with @_lifetime(self: immortal)
// ============================================================================
// Hypothesis: The CORRECT design uses ~Escapable on BOTH sequence and iterator.
//             @_lifetime(self: immortal) on next() tells the compiler "this mutation
//             is a pure state transition — the returned element doesn't borrow self."
//             This matches Swift.Span.Iterator and Sequence.Iterator.Borrowing.Protocol.

protocol FullEscSequence: ~Copyable, ~Escapable {
    associatedtype Element
    associatedtype Iterator: FullEscIterator where Iterator.Element == Element
    @_lifetime(copy self)
    consuming func makeIterator() -> Iterator
}

protocol FullEscIterator: ~Copyable, ~Escapable {
    associatedtype Element
    @_lifetime(self: immortal)
    mutating func next() -> Element?
}

struct FullIntSource: FullEscSequence {
    let values: [Int]

    struct Iterator: FullEscIterator {
        var index: Int = 0
        let values: [Int]

        @_lifetime(self: immortal)
        mutating func next() -> Int? {
            guard index < values.count else { return nil }
            defer { index += 1 }
            return values[index]
        }
    }

    // No @_lifetime needed — FullIntSource is Escapable, no lifetime to track.
    // The protocol declares @_lifetime(copy self) for ~Escapable conformers.
    consuming func makeIterator() -> Iterator {
        Iterator(values: values)
    }
}

func testV7() {
    let source = FullIntSource(values: [10, 20, 30])
    var iter = source.makeIterator()
    var results: [Int] = []
    while let e = iter.next() {
        results.append(e)
    }
    print("V7 results: \(results)")
    assert(results == [10, 20, 30], "V7 FAILED")
    print("V7: CONFIRMED — ~Escapable iterator with @_lifetime(self: immortal)")
}

// ============================================================================
// MARK: - V8: ~Escapable lazy map with ~Escapable iterator
// ============================================================================
// Hypothesis: The full ~Escapable design (both sequence and iterator) works
//             for lazy operator types — consuming chain, @_lifetime propagation.

struct FullEscMapped<Base: FullEscSequence & ~Copyable & ~Escapable, Input, Output>: ~Copyable, ~Escapable
    where Base.Element == Input
{
    let base: Base
    let transform: (Input) -> Output

    @_lifetime(copy base)
    init(base: consuming Base, transform: @escaping (Input) -> Output) {
        self.base = base
        self.transform = transform
    }
}

extension FullEscMapped: FullEscSequence where Base: ~Copyable & ~Escapable {
    typealias Element = Output

    struct Iter: FullEscIterator {
        var base: Base.Iterator
        let transform: (Input) -> Output

        @_lifetime(self: immortal)
        mutating func next() -> Output? {
            guard let e = base.next() else { return nil }
            return transform(e)
        }
    }

    @_lifetime(copy self)
    consuming func makeIterator() -> Iter {
        Iter(base: base.makeIterator(), transform: transform)
    }
}

func testV8() {
    let source = FullIntSource(values: [1, 2, 3, 4, 5])
    let mapped = FullEscMapped(base: source, transform: { $0 * 10 })

    print("V8 type: \(type(of: mapped))")

    var results: [Int] = []
    var iter = mapped.makeIterator()
    while let e = iter.next() {
        results.append(e)
    }
    print("V8 results: \(results)")
    assert(results == [10, 20, 30, 40, 50], "V8 FAILED")
    print("V8: CONFIRMED — ~Escapable lazy map with ~Escapable iterator")
}

// ============================================================================
// MARK: - V9: Chained full ~Escapable operators
// ============================================================================
// Hypothesis: The full ~Escapable design composes through chained operators.

struct FullEscFiltered<Base: FullEscSequence & ~Copyable & ~Escapable, ElementType>: ~Copyable, ~Escapable
    where Base.Element == ElementType
{
    let base: Base
    let predicate: (ElementType) -> Bool

    @_lifetime(copy base)
    init(base: consuming Base, predicate: @escaping (ElementType) -> Bool) {
        self.base = base
        self.predicate = predicate
    }
}

extension FullEscFiltered: FullEscSequence where Base: ~Copyable & ~Escapable {
    typealias Element = ElementType

    struct Iter: FullEscIterator {
        var base: Base.Iterator
        let predicate: (ElementType) -> Bool

        @_lifetime(self: immortal)
        mutating func next() -> ElementType? {
            while let e = base.next() {
                if predicate(e) { return e }
            }
            return nil
        }
    }

    @_lifetime(copy self)
    consuming func makeIterator() -> Iter {
        Iter(base: base.makeIterator(), predicate: predicate)
    }
}

func testV9() {
    let source = FullIntSource(values: [1, 2, 3, 4, 5])
    let mapped = FullEscMapped(base: source, transform: { $0 * 10 })
    let filtered = FullEscFiltered(base: mapped, predicate: { $0 > 20 })

    print("V9 type: \(type(of: filtered))")

    var results: [Int] = []
    var iter = filtered.makeIterator()
    while let e = iter.next() {
        results.append(e)
    }
    print("V9 results: \(results)")
    assert(results == [30, 40, 50], "V9 FAILED")
    print("V9: CONFIRMED — chained full ~Escapable operators compose")
}

// ============================================================================
// MARK: - Run all
// ============================================================================

extension String {
    static func * (lhs: String, rhs: Int) -> String {
        String(repeating: lhs, count: rhs)
    }
}

print("=" * 60)
print("ESCAPABLE LAZY SEQUENCE BORROWING EXPERIMENT")
print("=" * 60)
print()

testV1()
print()

testV2()
print()

testV3()
print()

testV4()
print()

testV5()
print()

testV6()
print()

testV7()
print()

testV8()
print()

testV9()
print()

print("=" * 60)
print("ALL VARIANTS COMPLETE")
print("=" * 60)
