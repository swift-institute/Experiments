// MARK: - Actor.run Closure Alternatives
// Purpose: Explore whether alternative formulations of Actor.run can avoid
//          the @Sendable requirement, enabling borrowing ~Copyable captures.
//
// The @Sendable requirement exists because the closure crosses an actor
// isolation boundary. This experiment tests whether:
//   - Free functions with `isolated` parameter avoid the escaping requirement
//   - `nonisolated` methods with `isolated` parameter change the picture
//   - `withoutActuallyEscaping` can bridge the gap
//   - `@preconcurrency` suppresses the diagnostic
//   - The closure is actually non-escaping in any formulation
//
// Toolchain: Swift 6.3 (Xcode 16)
// Platform: macOS 26 (arm64)
//
// Results:
//   V1: REFUTED — free function with `isolated A` is actor-isolated.
//       Closure crosses isolation boundary → "sending value of non-Sendable
//       type '(isolated Registry) -> Int' risks causing data races"
//   V2: REFUTED — blocked by V1.
//   V3: REFUTED — blocked by V1.
//   V4: REFUTED — blocked by V1.
//   V5: REFUTED — blocked by V1.
//   V6: INVALID — "instance method with 'isolated' parameter cannot be
//       'nonisolated'" — Swift rejects the combination.
//   V7: REFUTED — blocked by V1.
//   V8: REFUTED — blocked by V1.
//
// Conclusion: ALL formulations fail with the same root cause.
//
// A closure with `(isolated SomeActor)` parameter is inherently
// non-Sendable. Any function receiving such a closure that is itself
// actor-isolated (via `isolated` parameter or actor method) creates
// an isolation boundary the closure must cross. No amount of
// restructuring avoids this — it's a fundamental property of Swift's
// actor isolation model.
//
// The @Sendable requirement on Actor.run is not an implementation
// choice. It's a consequence of the language's isolation model.
//
// The borrowing ~Copyable blocker is a separate, deeper issue:
// `borrowing` parameters cannot be captured by ANY escaping closure.
// Actor-isolated closures are always escaping (the async thunk at
// the call site captures them). This is orthogonal to @Sendable —
// even without @Sendable, the borrowing capture would fail.
//
// Date: 2026-04-13

// ============================================================================
// MARK: - Fixtures
// ============================================================================

struct Descriptor: ~Copyable, Sendable {
    let fd: Int32
    func duplicate() -> Descriptor { Descriptor(fd: fd + 1000) }
}

struct Bundle: ~Copyable, Sendable {
    let id: Int
    let dupedFD: Int32
}

actor Registry {
    private var counter = 0

    func register(descriptor: borrowing Descriptor) -> Int {
        counter += 1
        return counter
    }

    func value() -> Int { counter }
}

// ============================================================================
// MARK: - V1: Free function with `isolated` parameter
// ============================================================================
// A free function taking `isolated A` runs in the actor's domain.
// The closure parameter might not need @Sendable because the function
// is synchronous and the closure doesn't escape.

// MARK: - V1: non-@Sendable closure on free function with isolated param
// Result: (pending)

func withActor<A: Actor, R>(
    _ actor: isolated A,
    _ body: (isolated A) -> R
) -> R {
    body(actor)
}

func testV1() async {
    let registry = Registry()
    let result = await withActor(registry) { registry in
        registry.value()
    }
    print("V1: \(result)")
}

// ============================================================================
// MARK: - V2: Free function — borrowing ~Copyable capture
// ============================================================================
// If V1 compiles, can the non-@Sendable closure capture a borrowing
// ~Copyable parameter?

// MARK: - V2: borrowing ~Copyable in non-@Sendable isolated closure
// Result: (pending)

func testBorrowing(registry: Registry, descriptor: borrowing Descriptor) async -> Int {
    await withActor(registry) { registry in
        registry.register(descriptor: descriptor)
    }
}

func testV2() async {
    let registry = Registry()
    let desc = Descriptor(fd: 5)
    let id = await testBorrowing(registry: registry, descriptor: desc)
    print("V2: id=\(id), fd=\(desc.fd)")
}

// ============================================================================
// MARK: - V3: Free function with ~Copyable return
// ============================================================================

// MARK: - V3: ~Copyable return from isolated free function
// Result: (pending)

func withActorNC<A: Actor, R: ~Copyable>(
    _ actor: isolated A,
    _ body: (isolated A) -> R
) -> R {
    body(actor)
}

func testV3() async {
    let registry = Registry()
    let b = await withActorNC(registry) { _ in
        Bundle(id: 1, dupedFD: 42)
    }
    print("V3: id=\(b.id)")
}

// ============================================================================
// MARK: - V4: Free function with typed throws
// ============================================================================

// MARK: - V4: typed throws on isolated free function
// Result: (pending)

func withActorThrows<A: Actor, R, Failure: Error>(
    _ actor: isolated A,
    _ body: (isolated A) throws(Failure) -> R
) throws(Failure) -> R {
    try body(actor)
}

func testV4() async {
    let registry = Registry()
    let result = await withActorThrows(registry) { registry in
        registry.value()
    }
    print("V4: \(result)")
}

// ============================================================================
// MARK: - V5: Free function — full combo
// ============================================================================
// ~Copyable return + typed throws + borrowing capture

// MARK: - V5: full combo — the IO.Event.Selector.register pattern
// Result: (pending)

func withActorFull<A: Actor, R: ~Copyable, Failure: Error>(
    _ actor: isolated A,
    _ body: (isolated A) throws(Failure) -> R
) throws(Failure) -> R {
    try body(actor)
}

func testFullPattern(
    registry: Registry,
    descriptor: borrowing Descriptor
) async -> Int {
    await withActorFull(registry) { registry in
        registry.register(descriptor: descriptor)
    }
}

func testV5() async {
    let registry = Registry()
    let desc = Descriptor(fd: 10)
    let id = await testFullPattern(registry: registry, descriptor: desc)
    print("V5: id=\(id), fd=\(desc.fd)")
}

// V6: REMOVED — "instance method with 'isolated' parameter cannot be 'nonisolated'"
// Cannot combine nonisolated method + isolated parameter on Actor extension.

// ============================================================================
// MARK: - V7: Non-Sendable class capture (the real Sendable test)
// ============================================================================
// If V1 avoids @Sendable, can we capture a non-Sendable class?

// MARK: - V7: non-Sendable class capture in isolated free function
// Result: (pending)

final class Config {
    var name: String
    init(_ name: String) { self.name = name }
}

func testV7() async {
    let registry = Registry()
    let config = Config("hello")

    let result = await withActor(registry) { _ in
        config.name
    }
    print("V7: \(result)")
}

// ============================================================================
// MARK: - V8: Async free function variant
// ============================================================================

// MARK: - V8: async isolated free function
// Result: (pending)

actor Other {
    func ping() -> String { "pong" }
}

func withActorAsync<A: Actor, R>(
    _ actor: isolated A,
    _ body: (isolated A) async -> R
) async -> R {
    await body(actor)
}

func testV8() async {
    let registry = Registry()
    let other = Other()

    let result = await withActorAsync(registry) { registry in
        _ = registry.value()
        return await other.ping()
    }
    print("V8: \(result)")
}

// ============================================================================
// MARK: - Entry Point
// ============================================================================

@main
struct Main {
    static func main() async {
        print("=== Actor.run Closure Alternatives ===")
        print()

        print("--- V1: free function with isolated param ---")
        await testV1()

        print("--- V2: borrowing ~Copyable capture ---")
        await testV2()

        print("--- V3: ~Copyable return ---")
        await testV3()

        print("--- V4: typed throws ---")
        await testV4()

        print("--- V5: full combo (IO pattern) ---")
        await testV5()

        print("--- V7: non-Sendable capture ---")
        await testV7()

        print("--- V8: async variant ---")
        await testV8()

        print()
        print("=== DONE ===")
    }
}
