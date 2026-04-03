// MARK: - Escapable Lazy Sequence Borrowing
// Purpose: Validate ~Escapable lazy operator types with borrowing/consuming patterns
//   V1: Can a ~Escapable struct use @_lifetime(borrow)?
//   V2: Can protocols suppress both Copyable and Escapable? Do Copyable types conform?
//   V3: Can a ~Escapable consuming lazy map iterate via protocol conformance?
//   V4: Do chained ~Escapable consuming operators compose (map -> filter)?
//   V5: Does manual for-in desugaring work with inline ~Escapable temporaries?
//   V6: Can a @_lifetime(borrow self) extension method return a ~Escapable adapter?
//
// Toolchain: Apple Swift 6.2.3 (swiftlang-6.2.3.3.21)
// Platform: macOS 26.0 (arm64)
//
// Result: V1-V6 CONFIRMED; V7-V9 BLOCKED (toolchain regression)
//   V1: CONFIRMED — ~Escapable struct with @_lifetime(borrow) compiles and works
//   V2: CONFIRMED — protocol with ~Copyable & ~Escapable suppression, Copyable types conform
//   V3: CONFIRMED — ~Escapable consuming lazy map iterates via EscSequence conformance
//   V4: CONFIRMED — chained ~Escapable operators compose (EscFiltered<EscMapped<...>>)
//   V5: CONFIRMED — for-in desugaring works with inline ~Escapable temporaries
//   V6: CONFIRMED — @_lifetime(borrow self) extension returns scoped ~Escapable adapter
//   V7: BLOCKED — @_lifetime on protocol requirements now rejected for Escapable conformers
//   V8: BLOCKED — depends on V7 protocols
//   V9: BLOCKED — depends on V7 protocols
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
//   - REGRESSION: @_lifetime on protocol method requirements now emits
//     "invalid lifetime dependence on an Escapable result" when an Escapable type conforms.
//     V7-V9 protocols (FullEscSequence/FullEscIterator) are commented out pending toolchain fix.
// Date: 2026-02-25
//
// Origin: escapable-lazy-sequence-borrowing

enum V05_LazySequenceBorrowing {

    // ========================================================================
    // MARK: - V1: Basic ~Escapable struct with @_lifetime(borrow)
    // ========================================================================
    // Hypothesis: ~Escapable + @_lifetime(borrow) compiles and works.

    struct BorrowedView<T>: ~Escapable {
        let value: T

        @_lifetime(borrow source)
        init(source: borrowing T) {
            self.value = copy source
        }
    }

    static func testV1() {
        let x = 42
        let view = BorrowedView(source: x)
        print("V1 value: \(view.value)")
        assert(view.value == 42, "V1 FAILED")
        print("V1: CONFIRMED — ~Escapable struct with @_lifetime(borrow)")
    }

    // ========================================================================
    // MARK: - V2: Protocol with ~Copyable, ~Escapable suppression
    // ========================================================================

    protocol EscSequence: ~Copyable, ~Escapable {
        associatedtype Element
        associatedtype Iterator: EscIterator where Iterator.Element == Element
        consuming func makeIterator() -> Iterator
    }

    protocol EscIterator: ~Copyable {
        associatedtype Element
        mutating func next() -> Element?
    }

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

    static func testV2() {
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

    // ========================================================================
    // MARK: - V3: ~Escapable consuming lazy map with iteration
    // ========================================================================

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

    // ========================================================================
    // MARK: - V4: Chained ~Escapable operators (map -> filter)
    // ========================================================================

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

    static func testV3() {
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

    static func testV4() {
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

    // ========================================================================
    // MARK: - V5: for-in desugaring with inline ~Escapable temporary
    // ========================================================================

    static func testV5() {
        var results: [Int] = []
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

    // ========================================================================
    // MARK: - V6: @_lifetime(borrow self) extension method returning ~Escapable
    // ========================================================================

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

    static func testV6() {
        let source = IntSource(values: [1, 2, 3])
        let mapped = source.lazyMap { $0 * 5 }

        let results = mapped.collect()
        print("V6 results: \(results)")
        assert(results == [5, 10, 15], "V6 FAILED")
        print("V6: CONFIRMED — @_lifetime(borrow self) extension returns ~Escapable adapter")
    }

    // ========================================================================
    // MARK: - V7-V9: BLOCKED — @_lifetime on protocol requirements
    //
    // These protocols worked on Swift 6.2.3 but are now rejected by the
    // current toolchain. The error is:
    //   "invalid lifetime dependence on an Escapable result" (on protocol method)
    //   "invalid lifetime dependence on an Escapable target" (on conformer method)
    //
    // The CORRECT DESIGN insight remains valid: both sequence AND iterator
    // protocols should suppress ~Escapable, with @_lifetime(self: immortal)
    // on mutating func next(). This matches Swift.Span.Iterator. The toolchain
    // needs to allow @_lifetime on protocol requirements where conformers may
    // be Escapable (the annotation is only enforced for ~Escapable conformers).
    // ========================================================================

    // COMPILE ERROR (expected): invalid lifetime dependence on an Escapable result
    // protocol FullEscSequence: ~Copyable, ~Escapable {
    //     associatedtype Element
    //     associatedtype Iterator: FullEscIterator where Iterator.Element == Element
    //     @_lifetime(copy self)
    //     consuming func makeIterator() -> Iterator
    // }
    //
    // protocol FullEscIterator: ~Copyable, ~Escapable {
    //     associatedtype Element
    //     @_lifetime(self: immortal)
    //     mutating func next() -> Element?
    // }
    //
    // struct FullIntSource: FullEscSequence {
    //     let values: [Int]
    //     struct Iterator: FullEscIterator {
    //         var index: Int = 0
    //         let values: [Int]
    //         @_lifetime(self: immortal)
    //         mutating func next() -> Int? {
    //             guard index < values.count else { return nil }
    //             defer { index += 1 }
    //             return values[index]
    //         }
    //     }
    //     consuming func makeIterator() -> Iterator {
    //         Iterator(values: values)
    //     }
    // }
    //
    // V8: FullEscMapped<Base: FullEscSequence> — depends on above protocols
    // V9: FullEscFiltered<Base: FullEscSequence> — depends on above protocols

    // ========================================================================
    // MARK: - Run all
    // ========================================================================

    static func run() {
        print("=" + String(repeating: "=", count: 59))
        print("ESCAPABLE LAZY SEQUENCE BORROWING EXPERIMENT")
        print("=" + String(repeating: "=", count: 59))
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

        print("V7-V9: BLOCKED — @_lifetime on protocol requirements rejected for Escapable conformers")
        print()

        print("=" + String(repeating: "=", count: 59))
        print("V05 ALL VARIANTS COMPLETE")
        print("=" + String(repeating: "=", count: 59))
    }
}

// Conformance extensions for EscMapped and EscFiltered (must be at file scope)
extension V05_LazySequenceBorrowing.EscMapped: V05_LazySequenceBorrowing.EscSequence where Base: ~Copyable & ~Escapable {
    typealias Element = Output

    struct Iter: V05_LazySequenceBorrowing.EscIterator {
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

extension V05_LazySequenceBorrowing.EscFiltered: V05_LazySequenceBorrowing.EscSequence where Base: ~Copyable & ~Escapable {
    typealias Element = ElementType

    struct Iter: V05_LazySequenceBorrowing.EscIterator {
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

// Extension for lazyMap on IntSource (must be at file scope)
extension V05_LazySequenceBorrowing.IntSource {
    @_lifetime(borrow self)
    borrowing func lazyMap<Output>(_ transform: @escaping (Int) -> Output) -> V05_LazySequenceBorrowing.BorrowedMapped<Self, Output> {
        V05_LazySequenceBorrowing.BorrowedMapped(base: self, transform: transform)
    }
}
