// MARK: - Actor.run with ~Copyable Return
// Purpose: Determine whether Actor.run can support ~Copyable return types.
//          The existing run<R> signature implicitly requires R: Copyable.
//          IO.Event.Selector.register needs to return ~Copyable Bundle.
//
// Hypotheses:
//   H1: An Actor.run overload with `R: ~Copyable` compiles
//   H2: `@Sendable` closure can have `~Copyable` return type
//   H3: `sending` works with `~Copyable` return
//   H4: `isolated Self` parameter works with `~Copyable` closure return
//   H5: Typed throws `throws(Failure)` works with `~Copyable` return
//   H6: The combined signature compiles and is callable
//
// Toolchain: Swift 6.3 (Xcode 16)
// Platform: macOS 26 (arm64)
//
// Results:
//   H1: CONFIRMED — `R: ~Copyable` compiles in all variants (V2-V6)
//   H2: REFUTED without @Sendable — closure can't cross isolation boundary.
//       CONFIRMED with @Sendable — V3+ all compile and run.
//   H3: CONFIRMED — `sending` works with `~Copyable` return (V4, V6)
//   H4: CONFIRMED — `isolated Self` + `~Copyable` return works (all variants)
//   H5: CONFIRMED — typed throws + ~Copyable compiles and propagates (V4-throws)
//   H6: CONFIRMED — full signature compiles, callable, returns ~Copyable values.
//       Also works with ~Copyable ~Sendable types (Handle, V4-nonsendable).
//       Same-name overloads (Copyable vs ~Copyable) disambiguate correctly.
// Date: 2026-04-13

// ============================================================================
// MARK: - Variant 1: Basic ~Copyable return from actor method
// ============================================================================
// Baseline: can an actor method return a ~Copyable type at all?

// MARK: - Variant 1: Hypothesis — actor method can return ~Copyable
// Result: (pending)

struct Resource: ~Copyable, Sendable {
    let id: Int
    init(id: Int) { self.id = id }
}

actor Factory {
    private var counter = 0

    func make() -> Resource {
        counter += 1
        return Resource(id: counter)
    }
}

// ============================================================================
// MARK: - Variant 2: run with R: ~Copyable, no sending, no Sendable
// ============================================================================
// Simplest possible ~Copyable run: strip all transfer annotations.

// MARK: - Variant 2: Hypothesis — basic ~Copyable run compiles
// Result: (pending)

extension Actor {
    func runV2<R: ~Copyable, Failure: Error>(
        _ body: (isolated Self) throws(Failure) -> R
    ) throws(Failure) -> R {
        try body(self)
    }
}

// ============================================================================
// MARK: - Variant 3: Add @Sendable to closure
// ============================================================================
// @Sendable is needed because the closure crosses isolation boundaries.
// Does @Sendable work with ~Copyable return?

// MARK: - Variant 3: Hypothesis — @Sendable + ~Copyable return compiles
// Result: (pending)

extension Actor {
    func runV3<R: ~Copyable, Failure: Error>(
        _ body: @Sendable (isolated Self) throws(Failure) -> R
    ) throws(Failure) -> R {
        try body(self)
    }
}

// ============================================================================
// MARK: - Variant 4: Add sending to return
// ============================================================================
// `sending` transfers ownership across isolation boundary.
// Does `sending R` work when `R: ~Copyable`?

// MARK: - Variant 4: Hypothesis — sending + ~Copyable compiles
// Result: (pending)

extension Actor {
    func runV4<R: ~Copyable, Failure: Error>(
        _ body: @Sendable (isolated Self) throws(Failure) -> sending R
    ) throws(Failure) -> sending R {
        try body(self)
    }
}

// ============================================================================
// MARK: - Variant 5: Full signature (sync) — matches our production run
// ============================================================================

// MARK: - Variant 5: Hypothesis — full sync run with ~Copyable compiles
// Result: (pending)

// (V4 is already the full sync signature with ~Copyable)

// ============================================================================
// MARK: - Variant 6: Async variant with ~Copyable
// ============================================================================

// MARK: - Variant 6: Hypothesis — async run with ~Copyable compiles
// Result: (pending)

extension Actor {
    func runV6<R: ~Copyable, Failure: Error>(
        _ body: @Sendable (isolated Self) async throws(Failure) -> sending R
    ) async throws(Failure) -> sending R {
        try await body(self)
    }
}

// ============================================================================
// MARK: - Variant 7: Call-site tests
// ============================================================================
// Can we actually CALL these overloads with ~Copyable types?

// MARK: - Variant 7a: Return ~Copyable from sync run
// Result: (pending)

// testV2: REFUTED — without @Sendable, closure can't cross isolation boundary.
// Error: sending value of non-Sendable type '(isolated Factory) -> Resource'
func testV2() async {
    print("V2: REFUTED — @Sendable required")
}

func testV3() async {
    let factory = Factory()
    let r = await factory.runV3 { factory in
        factory.make()
    }
    print("V3: id=\(r.id)")
}

func testV4() async {
    let factory = Factory()
    let r = await factory.runV4 { factory in
        factory.make()
    }
    print("V4: id=\(r.id)")
}

func testV6() async {
    let factory = Factory()
    let r = await factory.runV6 { factory in
        factory.make()
    }
    print("V6: id=\(r.id)")
}

// ============================================================================
// MARK: - Variant 8: ~Copyable + typed throws combined
// ============================================================================

// MARK: - Variant 8: Hypothesis — ~Copyable return + typed throws at call site
// Result: (pending)

enum MakeError: Error { case outOfStock }

actor FailableFactory {
    private var remaining = 3

    func make() throws(MakeError) -> Resource {
        guard remaining > 0 else { throw .outOfStock }
        remaining -= 1
        return Resource(id: remaining)
    }
}

func testV4Throws() async {
    let factory = FailableFactory()

    do {
        let r = try await factory.runV4 { factory in
            try factory.make()
        }
        print("V4-throws: id=\(r.id)")
    } catch {
        print("V4-throws: error=\(error)")
    }
}

// ============================================================================
// MARK: - Variant 9: ~Copyable + ~Sendable (double non-conformance)
// ============================================================================
// Some real-world types are both ~Copyable and ~Sendable (e.g., file handles).
// Can run handle this?

// MARK: - Variant 9: Hypothesis — ~Copyable ~Sendable return compiles
// Result: (pending)

struct Handle: ~Copyable {
    let fd: Int32
    init(fd: Int32) { self.fd = fd }
    deinit { print("  Handle \(fd) closed") }
}

actor HandleFactory {
    private var nextFD: Int32 = 10
    func open() -> Handle {
        nextFD += 1
        return Handle(fd: nextFD)
    }
}

// testV2NonSendable: REFUTED — same as testV2
func testV2NonSendable() async {
    print("V2-nonsendable: REFUTED — @Sendable required")
}

func testV4NonSendable() async {
    let factory = HandleFactory()
    let h = await factory.runV4 { factory in
        factory.open()
    }
    print("V4-nonsendable: fd=\(h.fd)")
}

// ============================================================================
// MARK: - Variant 10: Overload coexistence
// ============================================================================
// Can the ~Copyable overload coexist with the Copyable one without ambiguity?

// MARK: - Variant 10: Hypothesis — both overloads resolve correctly
// Result: (pending)

extension Actor {
    // Copyable overload (matches our production version)
    func runCopyable<R, Failure: Error>(
        _ body: @Sendable (isolated Self) throws(Failure) -> sending R
    ) throws(Failure) -> sending R {
        try body(self)
    }

    // ~Copyable overload
    func runNonCopyable<R: ~Copyable, Failure: Error>(
        _ body: @Sendable (isolated Self) throws(Failure) -> sending R
    ) throws(Failure) -> sending R {
        try body(self)
    }
}

func testOverloadCopyable() async {
    let factory = Factory()
    // Int is Copyable — which overload wins?
    let x = await factory.runCopyable { _ in 42 }
    let y = await factory.runNonCopyable { _ in 42 }
    print("Copyable overload: \(x), ~Copyable overload: \(y)")
}

func testOverloadNonCopyable() async {
    let factory = Factory()
    // Resource is ~Copyable — only ~Copyable overload should match
    let r = await factory.runNonCopyable { factory in
        factory.make()
    }
    print("~Copyable via runNonCopyable: id=\(r.id)")
}

// ============================================================================
// MARK: - Variant 11: Same name overload (the real question)
// ============================================================================
// Can we name BOTH overloads `run` and have the compiler disambiguate
// based on whether R is Copyable or ~Copyable?

// MARK: - Variant 11: Hypothesis — same-name overloads disambiguate on Copyable
// Result: (pending)

extension Actor {
    func runBoth<R, Failure: Error>(
        _ body: @Sendable (isolated Self) throws(Failure) -> sending R
    ) throws(Failure) -> sending R {
        print("  → Copyable overload")
        return try body(self)
    }

    func runBoth<R: ~Copyable, Failure: Error>(
        _ body: @Sendable (isolated Self) throws(Failure) -> sending R
    ) throws(Failure) -> sending R {
        print("  → ~Copyable overload")
        return try body(self)
    }
}

func testSameNameCopyable() async {
    let factory = Factory()
    let x: Int = await factory.runBoth { _ in 42 }
    print("Same-name Copyable: \(x)")
}

func testSameNameNonCopyable() async {
    let factory = Factory()
    let r: Resource = await factory.runBoth { factory in
        return factory.make()
    }
    print("Same-name ~Copyable: id=\(r.id)")
}

// ============================================================================
// MARK: - Entry Point
// ============================================================================

@main
struct Main {
    static func main() async {
        print("=== Actor.run ~Copyable Return Experiment ===")
        print()

        print("--- V2: basic ~Copyable ---")
        await testV2()

        print("--- V3: @Sendable + ~Copyable ---")
        await testV3()

        print("--- V4: sending + ~Copyable ---")
        await testV4()

        print("--- V6: async + ~Copyable ---")
        await testV6()

        print("--- V4-throws: ~Copyable + typed throws ---")
        await testV4Throws()

        print("--- V2-nonsendable: ~Copyable ~Sendable ---")
        await testV2NonSendable()

        print("--- V4-nonsendable: sending ~Copyable ~Sendable ---")
        await testV4NonSendable()

        print("--- Overload Copyable ---")
        await testOverloadCopyable()

        print("--- Overload ~Copyable ---")
        await testOverloadNonCopyable()

        print("--- Same-name Copyable ---")
        await testSameNameCopyable()

        print("--- Same-name ~Copyable ---")
        await testSameNameNonCopyable()

        print()
        print("=== DONE ===")
    }
}
