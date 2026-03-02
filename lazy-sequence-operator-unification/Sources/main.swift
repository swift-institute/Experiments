// MARK: - Lazy Sequence Operator Unification
// Purpose: Validate claims from sequence-operator-unification.md v2.0:
//   V1: Can one type conditionally conform to both a sync sequence protocol and AsyncSequence?
//   V1b: Do chained operators (map→filter) work for both sync and async paths?
//   V2: Do ~Copyable containers work with lazy operators (consuming chain)?
//   V2b: Do chained lazy operators work with ~Copyable containers?
//   V5: Can lazy Filter avoid the Copyable constraint that eager filter requires?
//   V6: Does async isolation preservation work through the shared type?
//
// Toolchain: Apple Swift 6.2.3 (swiftlang-6.2.3.3.21)
// Platform: macOS 26.0 (arm64)
//
// Result: ALL CONFIRMED (7/7 variants)
//   V1-sync:  CONFIRMED — Mapped<ArraySequence<Int>, Int, Int> iterates correctly
//   V1-async: CONFIRMED — same Mapped type iterates via for-await
//   V1b-sync: CONFIRMED — Filtered<Mapped<...>> chains correctly
//   V1b-async: CONFIRMED — same chained types iterate via for-await
//   V2:  CONFIRMED — Mapped<NCSequence, Int, Int> works with ~Copyable container
//   V2b: CONFIRMED — Filtered<Mapped<NCSequence, ...>> chains with ~Copyable container
//   V6:  CONFIRMED — sync closure in shared type preserves @MainActor isolation
// Date: 2026-02-25

import Foundation

// ============================================================================
// MARK: - Minimal sync sequence protocol (mirrors Sequence.Protocol)
// ============================================================================

protocol SyncSequence: ~Copyable {
    associatedtype Element: ~Copyable
    associatedtype Iterator: SyncIterator where Iterator.Element == Element
    consuming func makeIterator() -> Iterator
}

protocol SyncIterator: ~Copyable {
    associatedtype Element: ~Copyable
    mutating func next() -> Element?
}

// ============================================================================
// MARK: - V1: Conditional dual conformance (sync protocol + AsyncSequence)
// ============================================================================

// Hypothesis: A single generic struct can conditionally conform to both
// SyncSequence and AsyncSequence depending on Base's conformances.

struct Mapped<Base: ~Copyable, Input, Output>: ~Copyable {
    let base: Base
    let transform: (Input) -> Output
}

extension Mapped: Copyable where Base: Copyable {}

// Sync conformance: when Base is a SyncSequence
extension Mapped: SyncSequence where Base: SyncSequence & ~Copyable, Base.Element == Input {
    typealias Element = Output

    struct SyncIter: SyncIterator {
        var base: Base.Iterator
        let transform: (Input) -> Output

        mutating func next() -> Output? {
            guard let e = base.next() else { return nil }
            return transform(e)
        }
    }

    consuming func makeIterator() -> SyncIter {
        SyncIter(base: base.makeIterator(), transform: transform)
    }
}

// Async conformance: when Base is an AsyncSequence
extension Mapped: AsyncSequence where Base: AsyncSequence & Copyable, Base.Element == Input {
    typealias Element = Output

    struct AsyncIterator: AsyncIteratorProtocol {
        var base: Base.AsyncIterator
        let transform: (Input) -> Output

        mutating func next(
            isolation actor: isolated (any Actor)? = #isolation
        ) async -> Output? {
            guard let e = try? await base.next(isolation: actor) else { return nil }
            return transform(e)
        }
    }

    func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(base: base.makeAsyncIterator(), transform: transform)
    }
}

// ============================================================================
// MARK: - V1b: Filtered (inspecting adapter)
// ============================================================================

struct Filtered<Base: ~Copyable, ElementType>: ~Copyable {
    let base: Base
    let predicate: (ElementType) -> Bool
}

extension Filtered: Copyable where Base: Copyable {}

extension Filtered: SyncSequence where Base: SyncSequence & ~Copyable, Base.Element == ElementType {
    typealias Element = ElementType

    struct SyncIter: SyncIterator {
        var base: Base.Iterator
        let predicate: (ElementType) -> Bool

        mutating func next() -> ElementType? {
            while let e = base.next() {
                if predicate(e) { return e }
            }
            return nil
        }
    }

    consuming func makeIterator() -> SyncIter {
        SyncIter(base: base.makeIterator(), predicate: predicate)
    }
}

extension Filtered: AsyncSequence where Base: AsyncSequence & Copyable, Base.Element == ElementType {
    typealias Element = ElementType

    struct AsyncIterator: AsyncIteratorProtocol {
        var base: Base.AsyncIterator
        let predicate: (ElementType) -> Bool

        mutating func next(
            isolation actor: isolated (any Actor)? = #isolation
        ) async -> ElementType? {
            while let e = try? await base.next(isolation: actor) {
                if predicate(e) { return e }
            }
            return nil
        }
    }

    func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(base: base.makeAsyncIterator(), predicate: predicate)
    }
}

// ============================================================================
// MARK: - Test fixtures
// ============================================================================

// Simple sync sequence (Copyable)
struct ArraySequence<E>: SyncSequence {
    typealias Element = E
    let values: [E]

    struct Iterator: SyncIterator {
        var index: Int = 0
        let values: [E]
        mutating func next() -> E? {
            guard index < values.count else { return nil }
            defer { index += 1 }
            return values[index]
        }
    }

    consuming func makeIterator() -> Iterator {
        Iterator(values: values)
    }
}

// Simple async sequence
struct AsyncArraySequence<E: Sendable>: AsyncSequence, Sendable {
    typealias Element = E
    let values: [E]

    struct Iterator: AsyncIteratorProtocol {
        var index: Int = 0
        let values: [E]
        mutating func next(
            isolation actor: isolated (any Actor)? = #isolation
        ) async -> E? {
            guard index < values.count else { return nil }
            defer { index += 1 }
            return values[index]
        }
    }

    func makeAsyncIterator() -> Iterator {
        Iterator(values: values)
    }
}

// ~Copyable sync sequence
struct NCSequence: ~Copyable, SyncSequence {
    typealias Element = Int
    let count: Int

    struct Iterator: SyncIterator {
        var current: Int
        let end: Int
        mutating func next() -> Int? {
            guard current < end else { return nil }
            defer { current += 1 }
            return current
        }
    }

    consuming func makeIterator() -> Iterator {
        Iterator(current: 0, end: count)
    }
}

// ============================================================================
// MARK: - Execution
// ============================================================================

// --- V1: Sync path ---
func testV1Sync() {
    let source = ArraySequence(values: [1, 2, 3, 4, 5])
    let mapped = Mapped(base: source, transform: { $0 * 10 })

    print("V1-sync type: \(type(of: mapped))")

    var results: [Int] = []
    var iter = mapped.makeIterator()
    while let e = iter.next() {
        results.append(e)
    }
    print("V1-sync results: \(results)")
    assert(results == [10, 20, 30, 40, 50], "V1-sync FAILED")
    print("V1-sync: CONFIRMED")
}

// --- V1: Async path ---
func testV1Async() async {
    let source = AsyncArraySequence(values: [1, 2, 3, 4, 5])
    let mapped = Mapped(base: source, transform: { $0 * 10 })

    print("V1-async type: \(type(of: mapped))")

    var results: [Int] = []
    for await e in mapped {
        results.append(e)
    }
    print("V1-async results: \(results)")
    assert(results == [10, 20, 30, 40, 50], "V1-async FAILED")
    print("V1-async: CONFIRMED")
}

// --- V1b: Chained sync (map then filter) ---
func testV1bChainedSync() {
    let source = ArraySequence(values: [1, 2, 3, 4, 5])
    let mapped = Mapped(base: source, transform: { $0 * 10 })
    let filtered = Filtered(base: mapped, predicate: { $0 > 20 })

    print("V1b-chained type: \(type(of: filtered))")

    var results: [Int] = []
    var iter = filtered.makeIterator()
    while let e = iter.next() {
        results.append(e)
    }
    print("V1b-chained results: \(results)")
    assert(results == [30, 40, 50], "V1b-chained FAILED")
    print("V1b-chained: CONFIRMED")
}

// --- V1b: Chained async ---
func testV1bChainedAsync() async {
    let source = AsyncArraySequence(values: [1, 2, 3, 4, 5])
    let mapped = Mapped(base: source, transform: { $0 * 10 })
    let filtered = Filtered(base: mapped, predicate: { $0 > 20 })

    print("V1b-chained-async type: \(type(of: filtered))")

    var results: [Int] = []
    for await e in filtered {
        results.append(e)
    }
    print("V1b-chained-async results: \(results)")
    assert(results == [30, 40, 50], "V1b-chained-async FAILED")
    print("V1b-chained-async: CONFIRMED")
}

// --- V2: ~Copyable container with lazy map ---
func testV2NoncopyableContainer() {
    let source = NCSequence(count: 5)
    let mapped = Mapped(base: source, transform: { $0 * 3 })

    print("V2 type: \(type(of: mapped))")

    var results: [Int] = []
    var iter = mapped.makeIterator()
    while let e = iter.next() {
        results.append(e)
    }
    print("V2 results: \(results)")
    assert(results == [0, 3, 6, 9, 12], "V2 FAILED")
    print("V2: CONFIRMED")
}

// --- V2b: ~Copyable container with chained lazy operators ---
func testV2bNoncopyableChained() {
    let source = NCSequence(count: 6)
    let mapped = Mapped(base: source, transform: { $0 * 2 })
    let filtered = Filtered(base: mapped, predicate: { $0 > 4 })

    var results: [Int] = []
    var iter = filtered.makeIterator()
    while let e = iter.next() {
        results.append(e)
    }
    print("V2b results: \(results)")
    assert(results == [6, 8, 10], "V2b FAILED")
    print("V2b: CONFIRMED")
}

// --- V6: Async isolation preservation through shared type ---
@MainActor func testV6AsyncIsolation() async {
    let source = AsyncArraySequence(values: [1, 2, 3])
    nonisolated(unsafe) var allOnMain = true

    let checked = Mapped(base: source, transform: { (value: Int) -> Int in
        if !Thread.isMainThread { allOnMain = false }
        return value * 2
    })

    var results: [Int] = []
    for await e in checked {
        results.append(e)
    }
    print("V6 results: \(results)")
    assert(results == [2, 4, 6], "V6 FAILED")
    print("V6 isolation allOnMain: \(allOnMain)")
    if allOnMain {
        print("V6: CONFIRMED — sync closure in shared type preserves MainActor isolation")
    } else {
        print("V6: REFUTED — sync closure in shared type does NOT preserve isolation")
    }
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
print("LAZY SEQUENCE OPERATOR UNIFICATION EXPERIMENT")
print("=" * 60)
print()

testV1Sync()
print()

testV1bChainedSync()
print()

testV2NoncopyableContainer()
print()

testV2bNoncopyableChained()
print()

await testV1Async()
print()

await testV1bChainedAsync()
print()

await testV6AsyncIsolation()
print()

print("=" * 60)
print("ALL VARIANTS COMPLETE")
print("=" * 60)
