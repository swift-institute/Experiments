// Toolchain: Swift 6.3.1 (2026-04-30) — anchor added during Phase 7a sweep [EXP-007a]
// Revalidated: Swift 6.3.1 (2026-04-30) — STILL PRESENT
//
// ===----------------------------------------------------------------------===//
// EXPERIMENT: Full Suppression Approach
// ===----------------------------------------------------------------------===//
//
// CONFIRMED so far:
// - Protocol with ~Copyable, ~Escapable compiles (TEST 1-2)
// - associatedtype Iterator: IterP & ~Copyable & ~Escapable is required (TEST 3-5)
//
// NOW TESTING:
// - Full suppression: Base, lazy type, and Iterator all suppress both
// - Conditional conformances restore Copyable/Escapable
//
// ===----------------------------------------------------------------------===//

// MARK: - Protocols

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

print("Protocols: OK")

// MARK: - Concrete Escapable conformer

struct ConcreteSeq: SeqP {
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

func testConcrete() {
    let s = ConcreteSeq(data: [1, 2, 3])
    var iter = s.makeIterator()
    var sum = 0
    while let n = iter.next() { sum += n }
    print("Concrete conformer: \(sum == 6 ? "OK" : "FAIL")")
}

testConcrete()

// MARK: - LazyMap: Full suppression on everything

struct LazyMap<
    Base: SeqP & ~Copyable & ~Escapable,
    Input, Output
>: ~Copyable, ~Escapable where Base.Element == Input {
    let _base: Base
    let _transform: (Input) -> Output

    @_lifetime(copy base)
    init(base: consuming Base, transform: @escaping (Input) -> Output) {
        self._base = base
        self._transform = transform
    }

    struct Iter: ~Copyable, ~Escapable, IterP {
        var _base: Base.Iterator
        let _transform: (Input) -> Output

        @_lifetime(copy base)
        init(base: consuming Base.Iterator, transform: @escaping (Input) -> Output) {
            self._base = base
            self._transform = transform
        }

        @_lifetime(self: immortal)
        mutating func next() -> Output? {
            guard let element = _base.next() else { return nil }
            return _transform(element)
        }
    }
}

extension LazyMap: Copyable where Base: Copyable & ~Escapable {}
extension LazyMap: Escapable where Base: Escapable & ~Copyable {}

extension LazyMap: SeqP where Base: ~Copyable & ~Escapable {
    @_lifetime(copy self)
    consuming func makeIterator() -> Iter {
        Iter(base: _base.makeIterator(), transform: _transform)
    }
}

func testLazyMap() {
    let s = ConcreteSeq(data: [1, 2, 3])
    let mapped = LazyMap(base: s, transform: { $0 * 10 })
    var iter = mapped.makeIterator()
    var results: [Int] = []
    while let n = iter.next() { results.append(n) }
    print("LazyMap: \(results == [10, 20, 30] ? "OK" : "FAIL (\(results))")")
}

testLazyMap()

// MARK: - LazyFilter: Full suppression

struct LazyFilter<
    Base: SeqP & ~Copyable & ~Escapable
>: ~Copyable, ~Escapable {
    let _base: Base
    let _predicate: (borrowing Base.Element) -> Bool

    @_lifetime(copy base)
    init(base: consuming Base, predicate: @escaping (borrowing Base.Element) -> Bool) {
        self._base = base
        self._predicate = predicate
    }

    struct Iter: ~Copyable, ~Escapable, IterP {
        var _base: Base.Iterator
        let _predicate: (borrowing Base.Element) -> Bool

        @_lifetime(copy base)
        init(base: consuming Base.Iterator, predicate: @escaping (borrowing Base.Element) -> Bool) {
            self._base = base
            self._predicate = predicate
        }

        @_lifetime(self: immortal)
        mutating func next() -> Base.Element? {
            while let element = _base.next() {
                if _predicate(element) { return element }
            }
            return nil
        }
    }
}

extension LazyFilter: Copyable where Base: Copyable & ~Escapable {}
extension LazyFilter: Escapable where Base: Escapable & ~Copyable {}

extension LazyFilter: SeqP where Base: ~Copyable & ~Escapable {
    @_lifetime(copy self)
    consuming func makeIterator() -> Iter {
        Iter(base: _base.makeIterator(), predicate: _predicate)
    }
}

func testLazyFilter() {
    let s = ConcreteSeq(data: [1, 2, 3, 4, 5, 6])
    let filtered = LazyFilter(base: s, predicate: { $0 % 2 == 0 })
    var iter = filtered.makeIterator()
    var results: [Int] = []
    while let n = iter.next() { results.append(n) }
    print("LazyFilter: \(results == [2, 4, 6] ? "OK" : "FAIL (\(results))")")
}

testLazyFilter()

// MARK: - Protocol extensions: map, filter, collect

extension SeqP where Self: ~Copyable & ~Escapable {
    @_lifetime(copy self)
    consuming func map<Output>(
        _ transform: @escaping (Element) -> Output
    ) -> LazyMap<Self, Element, Output> {
        LazyMap(base: self, transform: transform)
    }

    @_lifetime(copy self)
    consuming func filter(
        _ predicate: @escaping (borrowing Element) -> Bool
    ) -> LazyFilter<Self> {
        LazyFilter(base: self, predicate: predicate)
    }
}

extension SeqP where Self: ~Copyable & ~Escapable, Element: Copyable {
    @_lifetime(copy self)
    consuming func collect() -> [Element] {
        var result: [Element] = []
        var iter = self.makeIterator()
        while let element = iter.next() {
            result.append(element)
        }
        return result
    }
}

// MARK: - Chaining test

func testChain() {
    let s = ConcreteSeq(data: [1, 2, 3, 4, 5])
    let result = s.map { $0 * 2 }.filter { $0 > 4 }.collect()
    print("Chain map→filter→collect: \(result == [6, 8, 10] ? "OK" : "FAIL (\(result))")")
}

testChain()

// MARK: - Escape scope test

func makeDoubled(_ s: ConcreteSeq) -> LazyMap<ConcreteSeq, Int, Int> {
    s.map { $0 * 3 }
}

func testEscape() {
    let s = ConcreteSeq(data: [1, 2, 3])
    let lazy = makeDoubled(s)
    let result = lazy.collect()
    print("Escape scope: \(result == [3, 6, 9] ? "OK" : "FAIL (\(result))")")
}

testEscape()

// MARK: - Summary

print()
print("===== ALL TESTS =====")
