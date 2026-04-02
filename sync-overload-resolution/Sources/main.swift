// sync-overload-resolution experiment
//
// PURPOSE: Determine whether a sync-closure overload of `map`/`filter` defined
// on `extension AsyncSequence` wins overload resolution over the stdlib's
// async-closure overload (AsyncMapSequence, AsyncFilterSequence).
//
// HYPOTHESES:
//   1. `source.map { $0 * 2 }` (sync closure) resolves to our Isolated.Map,
//      NOT to the stdlib's AsyncMapSequence, because the sync overload is a
//      more specific match when the closure body is synchronous.
//   2. Chaining `.map { ... }.filter { ... }` produces
//      Isolated.Filter<Isolated.Map<...>>.
//   3. Explicitly async closures still resolve to the stdlib overloads.
//   4. Values produced through our types are correct.
//   5. Isolation is preserved through the concrete pipeline.
//
// TOOLCHAIN: Swift 6.2 (Xcode 26 beta)
// PLATFORM: macOS 26
// DATE: 2026-02-25
//
// Result: PARTIALLY CONFIRMED — sync overload wins resolution but isolation lost at sync-to-async closure storage boundary
//
// FINDINGS:
//   1. CONFIRMED — `source.map { $0 * 2 }` resolves to Isolated.Map, not
//      AsyncMapSequence. The sync overload wins overload resolution.
//
//   2. CONFIRMED — `.map { }.filter { }` produces Filter<Map<Produce<Int>, Int>>
//      (our concrete chain), not AsyncFilterSequence<AsyncMapSequence<...>>.
//
//   3. CONFIRMED — `source.map { value -> Int in await ...; return ... }`
//      resolves to AsyncMapSequence (stdlib wins for async closures).
//
//   4. CONFIRMED — Values [2, 4, 6] are correct through our types.
//
//   5. REFUTED — Isolation is NOT preserved. The sync closure `(Element) -> Output`
//      is stored into the `(Element) async -> Output` property. This conversion
//      wraps the sync closure in a new async closure that is born in a nonisolated
//      context (the `map` method itself is sync/nonisolated). The resulting async
//      closure does not inherit caller isolation.
//
// KEY INSIGHT:
//   Overload resolution works perfectly — the compiler correctly prefers the
//   sync-closure overload. BUT isolation is lost at the storage boundary.
//   The `map` method is synchronous, so it runs in a nonisolated context.
//   When the sync closure `(Element) -> Output` is implicitly converted to
//   `(Element) async -> Output` for storage, the wrapper async closure is
//   created in that nonisolated context and thus runs on the cooperative pool.
//
//   This is the same finding as Test I from stream-isolation-preservation:
//   "sync map() breaks isolation because closures inside it are born without
//   isolation." The fix found there (Test J) was to make map() async, but
//   that has ergonomic cost (`await stream.map { ... }`).
//
//   For concrete types, the correct fix is to store the closure AS sync:
//   `let transform: (Element) -> Output` and call it synchronously from
//   within the async `next()` method. Since `next()` inherits caller isolation,
//   the sync call runs in the same isolation domain.

import Foundation

// ============================================================================
// INFRASTRUCTURE
// ============================================================================

nonisolated(unsafe) let mainQueueKey = DispatchSpecificKey<Bool>()

func setupMainQueueDetection() {
    DispatchQueue.main.setSpecific(key: mainQueueKey, value: true)
}

nonisolated func isOnMain() -> Bool {
    DispatchQueue.getSpecific(key: mainQueueKey) != nil
}

// ============================================================================
// SOURCE: Simple array-backed AsyncSequence
// ============================================================================

struct Produce<Element: Sendable>: AsyncSequence {
    let elements: [Element]

    init(_ elements: [Element]) {
        self.elements = elements
    }

    struct Iterator: AsyncIteratorProtocol {
        var index: Int = 0
        let elements: [Element]

        mutating func next() async -> Element? {
            guard index < elements.count else { return nil }
            defer { index += 1 }
            return elements[index]
        }
    }

    func makeAsyncIterator() -> Iterator {
        Iterator(elements: elements)
    }
}

// ============================================================================
// CONCRETE TYPES: Isolated.Map / Isolated.Filter
//
// These mirror our Async.Map / Async.Filter pattern. They store an
// `(Element) async -> Output` closure (nonsending under the feature) and
// use `next(isolation: #isolation)` to forward isolation.
// ============================================================================

enum Isolated {
    struct Map<Base: AsyncSequence, Output: Sendable>: AsyncSequence, @unchecked Sendable
        where Base: Sendable, Base.Element: Sendable
    {
        typealias Element = Output

        let base: Base
        let transform: (Base.Element) async -> Output

        struct Iterator: AsyncIteratorProtocol {
            var baseIterator: Base.AsyncIterator
            let transform: (Base.Element) async -> Output

            mutating func next() async -> Output? {
                guard let element = try? await baseIterator.next(isolation: #isolation) else {
                    return nil
                }
                return await transform(element)
            }
        }

        func makeAsyncIterator() -> Iterator {
            Iterator(baseIterator: base.makeAsyncIterator(), transform: transform)
        }
    }

    struct Filter<Base: AsyncSequence>: AsyncSequence, @unchecked Sendable
        where Base: Sendable, Base.Element: Sendable
    {
        typealias Element = Base.Element

        let base: Base
        let isIncluded: (Base.Element) async -> Bool

        struct Iterator: AsyncIteratorProtocol {
            var baseIterator: Base.AsyncIterator
            let isIncluded: (Base.Element) async -> Bool

            mutating func next() async -> Base.Element? {
                while true {
                    guard let element = try? await baseIterator.next(isolation: #isolation) else {
                        return nil
                    }
                    if await isIncluded(element) {
                        return element
                    }
                }
            }
        }

        func makeAsyncIterator() -> Iterator {
            Iterator(baseIterator: base.makeAsyncIterator(), isIncluded: isIncluded)
        }
    }
}

// ============================================================================
// SYNC CLOSURE OVERLOADS on AsyncSequence
//
// The key question: does the compiler prefer these sync-closure overloads
// over the stdlib's async-closure overloads when the closure body is sync?
// ============================================================================

extension AsyncSequence {
    func map<Output: Sendable>(
        _ transform: @escaping (Element) -> Output
    ) -> Isolated.Map<Self, Output> where Self: Sendable, Element: Sendable {
        Isolated.Map(base: self, transform: transform)
    }

    func filter(
        _ isIncluded: @escaping (Element) -> Bool
    ) -> Isolated.Filter<Self> where Self: Sendable, Element: Sendable {
        Isolated.Filter(base: self, isIncluded: isIncluded)
    }
}

// ============================================================================
// TESTS
// ============================================================================

@MainActor
func testOverloadResolution() async {
    print("=== Sync Overload Resolution Experiment ===")
    print("NonisolatedNonsendingByDefault: enabled")
    print()

    let source = Produce([1, 2, 3])

    // -----------------------------------------------------------------------
    // Test 1: Does sync closure give us our Isolated.Map type?
    // -----------------------------------------------------------------------
    let mapped = source.map { $0 * 2 }
    let mappedType = String(describing: type(of: mapped))
    // Our type prints as "Map<...>", stdlib prints as "AsyncMapSequence<...>"
    let isIsolatedMap = !mappedType.contains("AsyncMapSequence")
    print("Test 1 - sync map type: \(mappedType)")
    print("  -> Is Isolated.Map (not AsyncMapSequence)? \(isIsolatedMap ? "YES" : "NO (stdlib won)")")
    print()

    // -----------------------------------------------------------------------
    // Test 2: Does chaining produce Isolated.Filter<Isolated.Map<...>>?
    // -----------------------------------------------------------------------
    let filtered = source.map { $0 * 2 }.filter { $0 > 2 }
    let filteredType = String(describing: type(of: filtered))
    // Our type prints as "Filter<Map<...>>", stdlib prints as "AsyncFilterSequence<AsyncMapSequence<...>>"
    let isIsolatedChain = !filteredType.contains("AsyncFilterSequence") && !filteredType.contains("AsyncMapSequence")
    print("Test 2 - chained type: \(filteredType)")
    print("  -> Is Isolated chain (not AsyncFilterSequence)? \(isIsolatedChain ? "YES" : "NO (stdlib won)")")
    print()

    // -----------------------------------------------------------------------
    // Test 3: Does an async closure still give stdlib's AsyncMapSequence?
    // -----------------------------------------------------------------------
    let asyncMapped = source.map { value -> Int in
        try? await Task.sleep(for: .milliseconds(1))
        return value * 2
    }
    let asyncMappedType = String(describing: type(of: asyncMapped))
    let isStdlib = asyncMappedType.contains("AsyncMapSequence")
    print("Test 3 - async map type: \(asyncMappedType)")
    print("  -> Is AsyncMapSequence (stdlib)? \(isStdlib ? "YES" : "NO")")
    print()

    // -----------------------------------------------------------------------
    // Test 4: Verify values are correct through our types
    // -----------------------------------------------------------------------
    var results: [Int] = []
    for await value in mapped {
        results.append(value)
    }
    print("Test 4 - values: \(results)")
    print("  -> Correct? \(results == [2, 4, 6] ? "YES" : "NO")")
    print()

    // -----------------------------------------------------------------------
    // Test 5: Isolation preservation — does sync closure run on MainActor?
    // -----------------------------------------------------------------------
    let isolationSource = Produce([1, 2, 3])
    nonisolated(unsafe) var ranOnMain = true
    let isolationTest = isolationSource.map { value -> Int in
        if !isOnMain() { ranOnMain = false }
        return value * 2
    }
    var isolationResults: [Int] = []
    for await value in isolationTest {
        isolationResults.append(value)
    }
    print("Test 5 - isolation preserved: \(ranOnMain)")
    print("  -> Ran on MainActor? \(ranOnMain ? "YES" : "NO")")
    print()

    // -----------------------------------------------------------------------
    // Test 6: Filter isolation preservation
    // -----------------------------------------------------------------------
    nonisolated(unsafe) var filterOnMain = true
    let filterSource = Produce([1, 2, 3, 4, 5])
    let filterTest = filterSource.filter { value -> Bool in
        if !isOnMain() { filterOnMain = false }
        return value > 2
    }
    var filterResults: [Int] = []
    for await value in filterTest {
        filterResults.append(value)
    }
    print("Test 6 - filter isolation: \(filterOnMain)")
    print("  -> Ran on MainActor? \(filterOnMain ? "YES" : "NO")")
    print("  -> Values: \(filterResults)")
    print("  -> Correct? \(filterResults == [3, 4, 5] ? "YES" : "NO")")
    print()

    // -----------------------------------------------------------------------
    // Test 7: Chained pipeline isolation
    // -----------------------------------------------------------------------
    nonisolated(unsafe) var chainMapOnMain = true
    nonisolated(unsafe) var chainFilterOnMain = true
    let chainSource = Produce([1, 2, 3, 4, 5])
    let chainPipeline = chainSource
        .map { value -> Int in
            if !isOnMain() { chainMapOnMain = false }
            return value * 10
        }
        .filter { value -> Bool in
            if !isOnMain() { chainFilterOnMain = false }
            return value > 20
        }
    var chainResults: [Int] = []
    for await value in chainPipeline {
        chainResults.append(value)
    }
    print("Test 7 - chained pipeline isolation:")
    print("  -> map on MainActor?    \(chainMapOnMain ? "YES" : "NO")")
    print("  -> filter on MainActor? \(chainFilterOnMain ? "YES" : "NO")")
    print("  -> Values: \(chainResults)")
    print("  -> Correct? \(chainResults == [30, 40, 50] ? "YES" : "NO")")
    print()

    // -----------------------------------------------------------------------
    // Summary
    // -----------------------------------------------------------------------
    print("=== Summary ===")
    print("Sync map  -> Isolated.Map?           \(isIsolatedMap ? "YES" : "NO")")
    print("Sync chain -> Isolated types?         \(isIsolatedChain ? "YES" : "NO")")
    print("Async map -> AsyncMapSequence?        \(isStdlib ? "YES" : "NO")")
    print("Values correct?                       \(results == [2, 4, 6] ? "YES" : "NO")")
    print("Isolation preserved (map)?            \(ranOnMain ? "YES" : "NO")")
    print("Isolation preserved (filter)?         \(filterOnMain ? "YES" : "NO")")
    print("Isolation preserved (chain)?          \(chainMapOnMain && chainFilterOnMain ? "YES" : "NO")")
    print()
    print("KEY FINDING: Sync overload \(isIsolatedMap ? "WINS" : "LOSES") overload resolution.")
    if isIsolatedMap && !ranOnMain {
        print("HOWEVER: Isolation is NOT preserved. The sync closure is converted")
        print("to `(Element) async -> Output` when stored, and this conversion")
        print("creates a new async closure in a nonisolated context.")
    }
}

// ============================================================================
// MAIN
// ============================================================================

@main
struct Main {
    static func main() async {
        setupMainQueueDetection()
        await testOverloadResolution()
    }
}
