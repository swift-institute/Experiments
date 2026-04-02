// stream-isolation-preservation experiment
//
// PURPOSE: Determine the theoretical maximum isolation preservation for
// async sequence pipelines under NonisolatedNonsendingByDefault.
//
// HYPOTHESES:
//   A. Concrete AsyncSequence operator types (stdlib-style) preserve caller
//      isolation through next() chains — no @Sendable closure storage needed.
//   B. A non-Sendable iterator with `() async -> Element?` (nonsending by
//      default under NonisolatedNonsendingByDefault) preserves isolation.
//   C. A Sendable iterator MUST use `@Sendable () async -> Element?` which
//      breaks isolation — there is no middle ground.
//   D. The stdlib's `next(isolation:)` pattern forwards isolation correctly.
//
// TOOLCHAIN: Swift 6.2 (Xcode 26 beta)
// PLATFORM: macOS 26
// DATE: 2026-02-25
//
// Result: PARTIALLY CONFIRMED — concrete operator types preserve isolation; stdlib types and type-erased sync closures do not
//
// FINDINGS:
//   A. REFUTED — stdlib concrete types (AsyncMapSequence etc.) break isolation
//      because they were compiled WITHOUT NonisolatedNonsendingByDefault.
//      The stored closure types default to concurrent in the stdlib binary.
//      Our OWN concrete types compiled WITH the feature DO preserve isolation.
//
//   B. CONFIRMED — bare `() async -> Element?` in a non-Sendable struct
//      preserves caller isolation when the closure literal is created in an
//      isolated context (e.g., @MainActor function).
//
//   C. CONFIRMED — `@Sendable`, `@concurrent`, and `nonisolated(nonsending)
//      @Sendable` all break isolation on stored closures. No middle ground.
//
//   D. NOT TESTED DIRECTLY — but concrete types use `next(isolation: #isolation)`
//      and it works (Tests G, H).
//
// KEY DISCOVERIES:
//
//   1. CONCRETE TYPES PRESERVE ISOLATION (Tests G, H, K):
//      Our own Map/Filter types store the transform as a plain property
//      `(Element) async -> Output` (nonsending under the feature). The
//      nonsending `next()` method inherits caller isolation and calls the
//      stored transform, which then also runs in the caller's isolation.
//      This works for BOTH sync and async closures.
//
//   2. @unchecked Sendable DOES NOT BREAK ISOLATION (Test H):
//      Adding `@unchecked Sendable` to concrete types preserves isolation.
//      Only `@Sendable` on the CLOSURE TYPE ITSELF breaks isolation.
//      This means concrete types can be Sendable for crossing boundaries.
//
//   3. TYPE-ERASED SYNC map() BREAKS ISOLATION (Test I):
//      When `map()` is a sync method, closure literals created inside it
//      are in a nonisolated context — they don't capture actor isolation.
//      The closure is "born" without isolation and can never acquire it.
//
//   4. TYPE-ERASED ASYNC map() PRESERVES ISOLATION (Test J):
//      Making `map()` async (nonsending) fixes the problem — it inherits
//      the caller's isolation, so closure literals inside it capture it.
//      But this has an ergonomic cost: `await stream.map { ... }`.
//
//   5. LATE ERASURE PRESERVES ISOLATION (Tests L, M):
//      A concrete pipeline can be type-erased into EITHER a non-Sendable
//      OR a @Sendable wrapper and STILL preserve isolation. The closures
//      were already bound to the caller's isolation at concrete creation.
//      Even erasing into @Sendable () async -> Element? works because the
//      closure's captured state already includes the isolation context.
//
// ARCHITECTURE IMPLICATION:
//   The "best of all worlds" design is:
//   - Concrete operator types for pipeline composition (preserves isolation)
//   - @unchecked Sendable on concrete types (enables crossing boundaries)
//   - Type erasure to Async.Stream when needed (for merge, share, etc.)
//   - Isolation is captured at concrete operator creation, survives erasure
//   - Sync closures work (no async-only limitation)
//   - No language changes required

import Foundation
import Synchronization

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

nonisolated func isolationLabel() -> String {
    isOnMain() ? "MainActor ✓" : "cooperative pool ✗"
}

// ============================================================================
// TEST A: Concrete AsyncSequence types (stdlib-style)
//
// Does a chain of concrete operator types preserve caller isolation?
// The stdlib's AsyncMapSequence stores `(Element) async -> U` — NOT @Sendable.
// Under NonisolatedNonsendingByDefault this should be nonsending.
// ============================================================================

struct IntSource: AsyncSequence {
    typealias Element = Int
    let values: [Int]

    struct Iterator: AsyncIteratorProtocol {
        var index: Int = 0
        let values: [Int]

        mutating func next() async -> Int? {
            guard index < values.count else { return nil }
            defer { index += 1 }
            return values[index]
        }
    }

    func makeAsyncIterator() -> Iterator {
        Iterator(values: values)
    }
}

@MainActor
func testA() async {
    print("TEST A: Concrete AsyncSequence chain (stdlib .map/.filter)")
    print("  Testing: IntSource → .map → .filter → for await")

    let source = IntSource(values: [1, 2, 3, 4, 5])

    nonisolated(unsafe) var mapRanOnMain = true
    nonisolated(unsafe) var filterRanOnMain = true

    let pipeline = source
        .map { value -> String in
            if !isOnMain() { mapRanOnMain = false }
            return "[\(value)]"
        }
        .filter { value -> Bool in
            if !isOnMain() { filterRanOnMain = false }
            return true
        }

    var results: [String] = []
    for await item in pipeline {
        results.append(item)
    }

    print("  map closure isolation:    \(mapRanOnMain ? "MainActor ✓" : "cooperative pool ✗")")
    print("  filter closure isolation: \(filterRanOnMain ? "MainActor ✓" : "cooperative pool ✗")")
    print("  for-await body isolation: \(isolationLabel())")
    print("  elements received:        \(results.count)")
    print()
}

// ============================================================================
// TEST B: Non-Sendable iterator with bare `() async -> Element?`
//
// Under NonisolatedNonsendingByDefault, a bare async closure type should
// default to nonsending. If the containing struct is NOT Sendable, this
// should compile and preserve isolation.
// ============================================================================

struct NonsendingIterator: AsyncIteratorProtocol {
    // NOT @Sendable — should be nonsending under NonisolatedNonsendingByDefault
    let _next: () async -> Int?

    mutating func next() async -> Int? {
        await _next()
    }
}

struct NonsendingStream: AsyncSequence {
    typealias Element = Int
    // NOT @Sendable
    let _makeIterator: () -> NonsendingIterator

    func makeAsyncIterator() -> NonsendingIterator {
        _makeIterator()
    }
}

@MainActor
func testB() async {
    print("TEST B: Non-Sendable iterator, bare () async -> Int?")

    var index = 0
    let values = [10, 20, 30]

    let stream = NonsendingStream {
        NonsendingIterator {
            guard index < values.count else { return nil }
            defer { index += 1 }
            // Check isolation inside the _next closure
            return values[index]
        }
    }

    var nextRanOnMain = true
    var results: [Int] = []

    for await item in stream {
        results.append(item)
    }

    // The real test: did the _next closure execute on MainActor?
    // We need to check inside the closure itself.
    print("  for-await body isolation: \(isolationLabel())")
    print("  elements received:        \(results.count)")
    print()
}

// Variant: check isolation INSIDE the _next closure
@MainActor
func testB2() async {
    print("TEST B2: Non-Sendable _next — check isolation INSIDE closure")

    var index = 0
    let values = [10, 20, 30]
    var nextClosureOnMain = true

    let stream = NonsendingStream {
        NonsendingIterator {
            if !isOnMain() { nextClosureOnMain = false }
            guard index < values.count else { return nil }
            defer { index += 1 }
            return values[index]
        }
    }

    var results: [Int] = []
    for await item in stream {
        results.append(item)
    }

    print("  _next closure isolation:  \(nextClosureOnMain ? "MainActor ✓" : "cooperative pool ✗")")
    print("  for-await body isolation: \(isolationLabel())")
    print("  elements received:        \(results.count)")
    print()
}

// ============================================================================
// TEST C: Sendable iterator with `@Sendable () async -> Element?`
//
// This is the current Async.Stream design. Expected: breaks isolation.
// ============================================================================

struct SendableIterator: AsyncIteratorProtocol, Sendable {
    let _next: @Sendable () async -> Int?

    mutating func next() async -> Int? {
        await _next()
    }
}

struct SendableStream: AsyncSequence, Sendable {
    typealias Element = Int
    let _makeIterator: @Sendable () -> SendableIterator

    func makeAsyncIterator() -> SendableIterator {
        _makeIterator()
    }
}

@MainActor
func testC() async {
    print("TEST C: Sendable iterator, @Sendable () async -> Int?")

    let values = [100, 200, 300]
    nonisolated(unsafe) var nextClosureOnMain = true

    let stream = SendableStream {
        let index = Mutex(0)
        return SendableIterator {
            let i = index.withLock { i in
                defer { i += 1 }
                return i
            }
            if !isOnMain() { nextClosureOnMain = false }
            guard i < values.count else { return nil }
            return values[i]
        }
    }

    var results: [Int] = []
    for await item in stream {
        results.append(item)
    }

    print("  _next closure isolation:  \(nextClosureOnMain ? "MainActor ✓" : "cooperative pool ✗")")
    print("  for-await body isolation: \(isolationLabel())")
    print("  elements received:        \(results.count)")
    print()
}

// ============================================================================
// TEST D: @concurrent () async -> Element?
//
// Explicitly concurrent closure. Should break isolation (same as @Sendable
// for execution semantics).
// ============================================================================

struct ConcurrentIterator: AsyncIteratorProtocol, Sendable {
    let _next: @Sendable @concurrent () async -> Int?

    mutating func next() async -> Int? {
        await _next()
    }
}

@MainActor
func testD() async {
    print("TEST D: @concurrent () async -> Int?")

    let values = [1, 2, 3]
    nonisolated(unsafe) var nextClosureOnMain = true

    let index = Mutex(0)
    let iter = ConcurrentIterator {
        let i = index.withLock { i in
            defer { i += 1 }
            return i
        }
        if !isOnMain() { nextClosureOnMain = false }
        guard i < values.count else { return nil }
        return values[i]
    }

    var results: [Int] = []
    var iter2 = iter
    while let item = await iter2.next() {
        results.append(item)
    }

    print("  _next closure isolation:  \(nextClosureOnMain ? "MainActor ✓" : "cooperative pool ✗")")
    print("  for-await body isolation: \(isolationLabel())")
    print("  elements received:        \(results.count)")
    print()
}

// ============================================================================
// TEST E: Concrete chain with ASYNC closures
//
// The stdlib .map takes `(Element) async -> U`. Under NonisolatedNonsendingByDefault,
// the async closure should be nonsending and preserve isolation.
// This tests the async closure variant specifically.
// ============================================================================

@MainActor
func testE() async {
    print("TEST E: Concrete chain with async closures")

    let source = IntSource(values: [1, 2, 3])
    nonisolated(unsafe) var asyncMapOnMain = true

    let pipeline = source.map { value -> String in
        // Simulate async work
        try? await Task.sleep(for: .milliseconds(1))
        if !isOnMain() { asyncMapOnMain = false }
        return "async[\(value)]"
    }

    var results: [String] = []
    for await item in pipeline {
        results.append(item)
    }

    print("  async map isolation:      \(asyncMapOnMain ? "MainActor ✓" : "cooperative pool ✗")")
    print("  for-await body isolation: \(isolationLabel())")
    print("  elements received:        \(results.count)")
    print()
}

// ============================================================================
// TEST F: Sendable struct with nonisolated(nonsending) stored closure
//
// From our previous experiment, we know this combination exists (Clock.Any)
// but breaks isolation. Verify again in this context.
// ============================================================================

struct HybridIterator: Sendable {
    let _next: nonisolated(nonsending) @Sendable () async -> Int?
}

@MainActor
func testF() async {
    print("TEST F: nonisolated(nonsending) @Sendable stored closure")

    let values = [1, 2, 3]
    nonisolated(unsafe) var closureOnMain = true
    let index = Mutex(0)

    let iter = HybridIterator {
        let i = index.withLock { i in
            defer { i += 1 }
            return i
        }
        if !isOnMain() { closureOnMain = false }
        guard i < values.count else { return nil }
        return values[i]
    }

    // Call via a nonisolated(nonsending) method to see if method preserves
    // even though stored closure doesn't
    var results: [Int] = []
    while let item = await iter._next() {
        results.append(item)
    }

    print("  stored closure isolation: \(closureOnMain ? "MainActor ✓" : "cooperative pool ✗")")
    print("  for-await body isolation: \(isolationLabel())")
    print("  elements received:        \(results.count)")
    print()
}

// ============================================================================
// TEST G: Our own concrete Map type (compiled WITH NonisolatedNonsendingByDefault)
//
// Hypothesis: stdlib breaks because it was compiled without the feature.
// If we build our own AsyncMapSequence with the feature enabled, the
// closure type `(Element) async -> U` should be nonsending and preserve.
// ============================================================================

struct MyMap<Base: AsyncSequence, Output: Sendable>: AsyncSequence where Base.Element: Sendable {
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

struct MyFilter<Base: AsyncSequence>: AsyncSequence where Base.Element: Sendable {
    typealias Element = Base.Element

    let base: Base
    let predicate: (Base.Element) async -> Bool

    struct Iterator: AsyncIteratorProtocol {
        var baseIterator: Base.AsyncIterator
        let predicate: (Base.Element) async -> Bool

        mutating func next() async -> Base.Element? {
            while true {
                guard let element = try? await baseIterator.next(isolation: #isolation) else {
                    return nil
                }
                if await predicate(element) {
                    return element
                }
            }
        }
    }

    func makeAsyncIterator() -> Iterator {
        Iterator(baseIterator: base.makeAsyncIterator(), predicate: predicate)
    }
}

@MainActor
func testG() async {
    print("TEST G: Our own concrete Map/Filter (compiled with feature)")

    let source = IntSource(values: [1, 2, 3, 4, 5])
    nonisolated(unsafe) var mapOnMain = true
    nonisolated(unsafe) var filterOnMain = true

    let mapped = MyMap(base: source) { value -> String in
        if !isOnMain() { mapOnMain = false }
        return "[\(value)]"
    }
    let filtered = MyFilter(base: mapped) { value -> Bool in
        if !isOnMain() { filterOnMain = false }
        return true
    }

    var results: [String] = []
    for await item in filtered {
        results.append(item)
    }

    print("  map closure isolation:    \(mapOnMain ? "MainActor ✓" : "cooperative pool ✗")")
    print("  filter closure isolation: \(filterOnMain ? "MainActor ✓" : "cooperative pool ✗")")
    print("  for-await body isolation: \(isolationLabel())")
    print("  elements received:        \(results.count)")
    print()
}

// ============================================================================
// TEST H: Our own concrete Map with Sendable conformance
//
// Does adding Sendable to the concrete type break isolation?
// This tests whether Sendable conformance itself is the problem,
// or whether it's the @Sendable on stored closures.
// ============================================================================

struct MySendableMap<Base: AsyncSequence & Sendable, Output: Sendable>: AsyncSequence, @unchecked Sendable
    where Base.Element: Sendable
{
    typealias Element = Output

    let base: Base
    let transform: (Base.Element) async -> Output  // NOT @Sendable

    struct Iterator: AsyncIteratorProtocol {
        var baseIterator: Base.AsyncIterator
        let transform: (Base.Element) async -> Output  // NOT @Sendable

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

@MainActor
func testH() async {
    print("TEST H: Our concrete Map + @unchecked Sendable")

    let source = IntSource(values: [1, 2, 3])
    nonisolated(unsafe) var mapOnMain = true

    let mapped = MySendableMap(base: source) { value -> String in
        if !isOnMain() { mapOnMain = false }
        return "[\(value)]"
    }

    var results: [String] = []
    for await item in mapped {
        results.append(item)
    }

    print("  map closure isolation:    \(mapOnMain ? "MainActor ✓" : "cooperative pool ✗")")
    print("  for-await body isolation: \(isolationLabel())")
    print("  elements received:        \(results.count)")
    print()
}

// ============================================================================
// TEST I: Type-erased wrapper around nonsending _next
//
// Can we build a non-Sendable type-erased stream that preserves isolation?
// This is the "Path 2" from our analysis.
// ============================================================================

struct IsolatedStream<Element>: AsyncSequence {
    // NOT Sendable. Under NonisolatedNonsendingByDefault, this is nonsending.
    let _makeIterator: () -> IsolatedIterator<Element>

    struct IsolatedIterator<E>: AsyncIteratorProtocol {
        let _next: () async -> E?

        mutating func next() async -> E? {
            await _next()
        }
    }

    func makeAsyncIterator() -> IsolatedIterator<Element> {
        _makeIterator()
    }
}

extension IsolatedStream {
    func map<U>(_ transform: @escaping (Element) async -> U) -> IsolatedStream<U> {
        let base = self
        return IsolatedStream<U> {
            var iter = base.makeAsyncIterator()
            return IsolatedStream<U>.IsolatedIterator {
                guard let element = await iter.next() else { return nil }
                return await transform(element)
            }
        }
    }

    func filter(_ predicate: @escaping (Element) async -> Bool) -> IsolatedStream<Element> {
        let base = self
        return IsolatedStream<Element> {
            var iter = base.makeAsyncIterator()
            return IsolatedStream<Element>.IsolatedIterator {
                while true {
                    guard let element = await iter.next() else { return nil }
                    if await predicate(element) { return element }
                }
            }
        }
    }
}

@MainActor
func testI() async {
    print("TEST I: Non-Sendable type-erased stream (IsolatedStream)")

    var index = 0
    let values = [1, 2, 3, 4, 5]

    let source = IsolatedStream<Int> {
        IsolatedStream<Int>.IsolatedIterator {
            guard index < values.count else { return nil }
            defer { index += 1 }
            return values[index]
        }
    }

    nonisolated(unsafe) var mapOnMain = true
    nonisolated(unsafe) var filterOnMain = true

    let pipeline = source
        .map { value -> String in
            if !isOnMain() { mapOnMain = false }
            return "[\(value)]"
        }
        .filter { value -> Bool in
            if !isOnMain() { filterOnMain = false }
            return true
        }

    var results: [String] = []
    for await item in pipeline {
        results.append(item)
    }

    print("  map closure isolation:    \(mapOnMain ? "MainActor ✓" : "cooperative pool ✗")")
    print("  filter closure isolation: \(filterOnMain ? "MainActor ✓" : "cooperative pool ✗")")
    print("  for-await body isolation: \(isolationLabel())")
    print("  elements received:        \(results.count)")
    print()
}

// ============================================================================
// TEST J: Type-erased stream with ASYNC map (so closures inherit isolation)
//
// Theory: Test I broke because `map` is sync — closures inside it are created
// in a nonisolated context. If `map` is async (nonsending), it inherits the
// caller's isolation, and closure literals created inside it should too.
// ============================================================================

extension IsolatedStream {
    func asyncMap<U>(_ transform: @escaping (Element) async -> U) async -> IsolatedStream<U> {
        let base = self
        return IsolatedStream<U> {
            var iter = base.makeAsyncIterator()
            return IsolatedStream<U>.IsolatedIterator {
                guard let element = await iter.next() else { return nil }
                return await transform(element)
            }
        }
    }

    func asyncFilter(_ predicate: @escaping (Element) async -> Bool) async -> IsolatedStream<Element> {
        let base = self
        return IsolatedStream<Element> {
            var iter = base.makeAsyncIterator()
            return IsolatedStream<Element>.IsolatedIterator {
                while true {
                    guard let element = await iter.next() else { return nil }
                    if await predicate(element) { return element }
                }
            }
        }
    }
}

@MainActor
func testJ() async {
    print("TEST J: Type-erased stream with ASYNC map/filter")

    var index = 0
    let values = [1, 2, 3, 4, 5]

    let source = IsolatedStream<Int> {
        IsolatedStream<Int>.IsolatedIterator {
            guard index < values.count else { return nil }
            defer { index += 1 }
            return values[index]
        }
    }

    nonisolated(unsafe) var mapOnMain = true
    nonisolated(unsafe) var filterOnMain = true

    let pipeline = await source
        .asyncMap { value -> String in
            if !isOnMain() { mapOnMain = false }
            return "[\(value)]"
        }
    let filtered = await pipeline
        .asyncFilter { value -> Bool in
            if !isOnMain() { filterOnMain = false }
            return true
        }

    var results: [String] = []
    for await item in filtered {
        results.append(item)
    }

    print("  map closure isolation:    \(mapOnMain ? "MainActor ✓" : "cooperative pool ✗")")
    print("  filter closure isolation: \(filterOnMain ? "MainActor ✓" : "cooperative pool ✗")")
    print("  for-await body isolation: \(isolationLabel())")
    print("  elements received:        \(results.count)")
    print()
}

// ============================================================================
// TEST K: Concrete types with SYNC closures
//
// Tests G/H used sync closures in concrete types and they PRESERVED.
// But our earlier finding was "sync closures can't be nonsending."
// This tests more explicitly: does a sync closure in a concrete type
// preserve isolation because it's called FROM a nonsending next()?
// ============================================================================

@MainActor
func testK() async {
    print("TEST K: Concrete type, sync closure — detailed isolation check")

    let source = IntSource(values: [1, 2, 3])

    // Sync closure variant (not async)
    nonisolated(unsafe) var syncMapOnMain = true
    let mapped = MyMap(base: source) { (value: Int) -> String in
        if !isOnMain() { syncMapOnMain = false }
        return "sync[\(value)]"
    }

    var results: [String] = []
    for await item in mapped {
        results.append(item)
    }

    print("  sync closure isolation:   \(syncMapOnMain ? "MainActor ✓" : "cooperative pool ✗")")
    print("  for-await body isolation: \(isolationLabel())")
    print("  elements received:        \(results.count)")
    print()
}

// ============================================================================
// TEST L: Hybrid — concrete operators returning Async.Stream-like type erasure
//
// The "best of both worlds" attempt: use concrete types for the pipeline,
// but the final type IS type-erased. Does isolation survive the chain
// if we erase at the end?
// ============================================================================

struct TypeErasedIterator<Element>: AsyncIteratorProtocol {
    // NOT @Sendable — nonsending under feature
    let _next: () async -> Element?

    mutating func next() async -> Element? {
        await _next()
    }
}

struct TypeErasedStream<Element>: AsyncSequence {
    let _makeIterator: () -> TypeErasedIterator<Element>

    func makeAsyncIterator() -> TypeErasedIterator<Element> {
        _makeIterator()
    }
}

@MainActor
func testL() async {
    print("TEST L: Concrete pipeline → non-Sendable type-erased at end")

    let source = IntSource(values: [1, 2, 3, 4, 5])
    nonisolated(unsafe) var mapOnMain = true

    // Concrete chain first (preserves isolation per Test G)
    let concrete = MyMap(base: source) { value -> String in
        if !isOnMain() { mapOnMain = false }
        return "[\(value)]"
    }

    // Now erase into non-Sendable type-erased stream
    nonisolated(unsafe) var iter = concrete.makeAsyncIterator()
    let erased = TypeErasedStream<String> {
        TypeErasedIterator {
            await iter.next()
        }
    }

    var results: [String] = []
    for await item in erased {
        results.append(item)
    }

    print("  map closure isolation:    \(mapOnMain ? "MainActor ✓" : "cooperative pool ✗")")
    print("  for-await body isolation: \(isolationLabel())")
    print("  elements received:        \(results.count)")
    print()
}

// ============================================================================
// TEST M: Concrete pipeline erased via Sendable Async.Stream-style type
//
// Same as L, but the erased type is Sendable (like current Async.Stream).
// Does @Sendable on _next break isolation even at the end?
// ============================================================================

struct SendableErasedIterator<Element: Sendable>: AsyncIteratorProtocol, Sendable {
    let _next: @Sendable () async -> Element?

    mutating func next() async -> Element? {
        await _next()
    }
}

struct SendableErasedStream<Element: Sendable>: AsyncSequence, Sendable {
    let _makeIterator: @Sendable () -> SendableErasedIterator<Element>

    func makeAsyncIterator() -> SendableErasedIterator<Element> {
        _makeIterator()
    }
}

@MainActor
func testM() async {
    print("TEST M: Concrete pipeline → @Sendable type-erased at end")

    let source = IntSource(values: [1, 2, 3])
    nonisolated(unsafe) var mapOnMain = true

    let concrete = MySendableMap(base: source) { value -> String in
        if !isOnMain() { mapOnMain = false }
        return "[\(value)]"
    }

    // Erase into Sendable type (like Async.Stream)
    nonisolated(unsafe) var iter = concrete.makeAsyncIterator()
    let erased = SendableErasedStream {
        return SendableErasedIterator {
            await iter.next()
        }
    }

    var results: [String] = []
    for await item in erased {
        results.append(item)
    }

    print("  map closure isolation:    \(mapOnMain ? "MainActor ✓" : "cooperative pool ✗")")
    print("  for-await body isolation: \(isolationLabel())")
    print("  elements received:        \(results.count)")
    print()
}

// ============================================================================
// MAIN
// ============================================================================

@main
struct Main {
    static func main() async {
        setupMainQueueDetection()
        print("=== Stream Isolation Preservation Experiment ===")
        print("NonisolatedNonsendingByDefault: enabled")
        print()

        await testA()   // Concrete chain (stdlib)
        await testB()   // Non-Sendable, bare closure
        await testB2()  // Non-Sendable, check inside closure
        await testC()   // Sendable, @Sendable closure
        await testD()   // @concurrent closure
        await testE()   // Concrete chain, async closures
        await testF()   // nonsending @Sendable hybrid
        await testG()   // Our own concrete types (with feature)
        await testH()   // Our own concrete + @unchecked Sendable
        await testI()   // Non-Sendable type-erased stream
        await testJ()   // Type-erased with async map
        await testK()   // Concrete with sync closure
        await testL()   // Concrete → non-Sendable erasure
        await testM()   // Concrete → Sendable erasure

        print("=== Summary ===")
        print("See results above for isolation preservation per variant.")
    }
}
