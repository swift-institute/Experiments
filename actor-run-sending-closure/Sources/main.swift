// MARK: - Actor.run with `sending` Closure Parameter
// Purpose: Determine whether `sending` on the closure parameter can replace
//          `@Sendable` on the closure type, enabling capture of non-Sendable
//          and borrowing ~Copyable values.
//
// Hypotheses:
//   H1: `sending` closure parameter compiles as replacement for @Sendable
//   H2: Non-Sendable values can be captured in a `sending` closure
//   H3: `sending` closure + `sending` return compiles
//   H4: `sending` closure works with `isolated Self`
//   H5: `sending` closure works with typed throws
//   H6: `sending` closure works with ~Copyable return
//   H7: borrowing ~Copyable parameter can be captured in `sending` closure
//   H8: The full IO.Event.Selector.register pattern works
//
// Toolchain: Swift 6.3 (Xcode 16)
// Platform: macOS 26 (arm64)
//
// Results:
//   H1: REFUTED — "sending value of non-Sendable type '(isolated Registry)
//       -> sending Int' risks causing data races". The closure type itself
//       is non-Sendable (captures actor-isolated binding), and `sending`
//       requires the value to be in a disconnected region.
//   H2: REFUTED — "passing closure as a 'sending' parameter risks causing
//       data races between actor-isolated code and concurrent execution".
//       Non-Sendable captures prevent the closure from being disconnected.
//   H3: REFUTED — same as H1.
//   H4: N/A — blocked by H1.
//   H5: COMPILER BUG — "pattern that the region-based isolation checker
//       does not understand how to check. Please file a bug"
//       Triggered by sending closure + borrowing ~Copyable + typed throws.
//   H6: COMPILER BUG — same.
//   H7: COMPILER BUG — same (async variant).
//   H8: REFUTED — same as H1/H2.
//
// Conclusion: `sending` on the closure parameter is NOT a viable
// replacement for `@Sendable`. The closure crosses an actor isolation
// boundary, and `sending` requires the closure to be in a disconnected
// region. A closure capturing values from the caller's scope is not
// disconnected — the caller retains access to those values.
//
// The `@Sendable` requirement on Actor.run is correct and necessary.
// The borrowing ~Copyable blocker on IO.Event.Selector.register is a
// separate issue: `borrowing` parameters cannot be captured by ANY
// escaping closure (the borrow's lifetime is tied to the function scope).
// Date: 2026-04-13

// ============================================================================
// MARK: - Fixtures
// ============================================================================

/// Non-Sendable class
final class Config {
    var name: String
    init(_ name: String) { self.name = name }
}

/// ~Copyable Sendable resource
struct Resource: ~Copyable, Sendable {
    let id: Int
}

/// ~Copyable non-Sendable handle (simulates Kernel.Descriptor)
struct Descriptor: ~Copyable, Sendable {
    let fd: Int32
    init(fd: Int32) { self.fd = fd }

    /// Simulates dup — borrows self, returns new owned copy
    func duplicate() -> Descriptor { Descriptor(fd: fd + 1000) }
}

/// ~Copyable non-Sendable result (simulates IO.Event.Register.Bundle)
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

    func registerAndDup(descriptor: borrowing Descriptor) -> Bundle {
        counter += 1
        let duped = descriptor.duplicate()
        return Bundle(id: counter, dupedFD: duped.fd)
    }

    func value() -> Int { counter }

    enum Failure: Error { case full }
    func registerOrFail(descriptor: borrowing Descriptor) throws(Failure) -> Int {
        guard counter < 3 else { throw .full }
        counter += 1
        return counter
    }
}

// ============================================================================
// MARK: - Variant 1: Basic `sending` closure parameter
// ============================================================================

// MARK: - V1: Hypothesis — `sending` closure compiles
// Result: (pending)

extension Actor {
    func runS1<R, Failure: Error>(
        _ body: sending (isolated Self) throws(Failure) -> sending R
    ) throws(Failure) -> sending R {
        try body(self)
    }
}

func testV1() async {
    let registry = Registry()
    let result = await registry.runS1 { registry in
        registry.value()
    }
    print("V1: \(result)")
}

// ============================================================================
// MARK: - Variant 2: Capture non-Sendable value
// ============================================================================

// MARK: - V2: Hypothesis — non-Sendable capture allowed with `sending`
// Result: (pending)

func testV2() async {
    let registry = Registry()
    let config = Config("test")  // non-Sendable

    let result = await registry.runS1 { registry in
        // Can we read config here?
        return config.name
    }
    print("V2: \(result)")
}

// ============================================================================
// MARK: - Variant 3: ~Copyable return
// ============================================================================

// MARK: - V3: Hypothesis — sending closure + ~Copyable return
// Result: (pending)

extension Actor {
    func runS3<R: ~Copyable, Failure: Error>(
        _ body: sending (isolated Self) throws(Failure) -> sending R
    ) throws(Failure) -> sending R {
        try body(self)
    }
}

func testV3() async {
    let registry = Registry()
    let resource = await registry.runS3 { _ in
        Resource(id: 42)
    }
    print("V3: id=\(resource.id)")
}

// ============================================================================
// MARK: - Variant 4: Typed throws
// ============================================================================

// MARK: - V4: Hypothesis — sending closure + typed throws
// Result: (pending)

func testV4() async {
    let registry = Registry()
    let desc = Descriptor(fd: 1)

    do {
        for _ in 0..<4 {
            _ = try await registry.runS1 { registry in
                try registry.registerOrFail(descriptor: desc)
            }
        }
    } catch {
        print("V4: caught \(error)")
    }
}

// ============================================================================
// MARK: - Variant 5: borrowing ~Copyable parameter capture
// ============================================================================
// This is the critical test. Can a `sending` closure capture a
// `borrowing Descriptor` (the ~Copyable parameter)?

// MARK: - V5: Hypothesis — borrowing ~Copyable captured in sending closure
// Result: (pending)

func testBorrowing(registry: Registry, descriptor: borrowing Descriptor) async -> Int {
    await registry.runS1 { registry in
        registry.register(descriptor: descriptor)
    }
}

func testV5() async {
    let registry = Registry()
    let desc = Descriptor(fd: 5)
    let id = await testBorrowing(registry: registry, descriptor: desc)
    print("V5: id=\(id), original fd=\(desc.fd)")
}

// ============================================================================
// MARK: - Variant 6: Full IO pattern — borrow + dup + ~Copyable return
// ============================================================================
// Simulates IO.Event.Selector.register: borrow a descriptor, register
// inside the actor (which dups), return a ~Copyable Bundle.

// MARK: - V6: Hypothesis — full IO.Event.Selector.register pattern works
// Result: (pending)

func testFullIOPattern(
    registry: Registry,
    descriptor: borrowing Descriptor
) async -> Bundle {
    await registry.runS3 { registry in
        registry.registerAndDup(descriptor: descriptor)
    }
}

func testV6() async {
    let registry = Registry()
    let desc = Descriptor(fd: 10)
    let bundle = await testFullIOPattern(registry: registry, descriptor: desc)
    print("V6: id=\(bundle.id), dupedFD=\(bundle.dupedFD), originalFD=\(desc.fd)")
}

// ============================================================================
// MARK: - Variant 7: Async overload with sending closure
// ============================================================================

// MARK: - V7: Hypothesis — async + sending closure compiles
// Result: (pending)

extension Actor {
    func runS7<R, Failure: Error>(
        _ body: sending (isolated Self) async throws(Failure) -> sending R
    ) async throws(Failure) -> sending R {
        try await body(self)
    }
}

actor Other {
    func ping() -> String { "pong" }
}

func testV7() async {
    let registry = Registry()
    let other = Other()

    let result = await registry.runS7 { registry in
        _ = registry.value()
        return await other.ping()
    }
    print("V7: \(result)")
}

// ============================================================================
// MARK: - Variant 8: Coexistence with @Sendable overload
// ============================================================================
// Can `sending` and `@Sendable` overloads coexist with the same name?

// MARK: - V8: Hypothesis — overload resolution between sending and @Sendable
// Result: (pending)

extension Actor {
    func runDual_sendable<R, Failure: Error>(
        _ body: @Sendable (isolated Self) throws(Failure) -> sending R
    ) throws(Failure) -> sending R {
        print("  → @Sendable overload")
        return try body(self)
    }

    func runDual_sending<R, Failure: Error>(
        _ body: sending (isolated Self) throws(Failure) -> sending R
    ) throws(Failure) -> sending R {
        print("  → sending overload")
        return try body(self)
    }
}

func testV8() async {
    let registry = Registry()

    // @Sendable closure (explicitly)
    let a = await registry.runDual_sendable { registry in
        registry.value()
    }
    print("V8a (sendable): \(a)")

    // sending closure
    let b = await registry.runDual_sending { registry in
        registry.value()
    }
    print("V8b (sending): \(b)")

    // Non-Sendable capture — only sending overload should work
    let config = Config("hello")
    let c = await registry.runDual_sending { _ in
        config.name
    }
    print("V8c (sending + non-Sendable capture): \(c)")
}

// ============================================================================
// MARK: - Entry Point
// ============================================================================

@main
struct Main {
    static func main() async {
        print("=== Actor.run sending Closure Experiment ===")
        print()

        print("--- V1: basic sending closure ---")
        await testV1()

        print("--- V2: non-Sendable capture ---")
        await testV2()

        print("--- V3: ~Copyable return ---")
        await testV3()

        print("--- V4: typed throws ---")
        await testV4()

        print("--- V5: borrowing ~Copyable capture ---")
        await testV5()

        print("--- V6: full IO pattern ---")
        await testV6()

        print("--- V7: async + sending ---")
        await testV7()

        print("--- V8: coexistence ---")
        await testV8()

        print()
        print("=== DONE ===")
    }
}
