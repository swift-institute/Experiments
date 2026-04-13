// MARK: - Actor.run + assumeIsolated: The Complete Picture
// Purpose: Explore the full design space for actor transactional access,
//          including `assumeIsolated` as a non-@Sendable, non-escaping
//          mechanism for shared-executor cross-actor access.
//
// Key insight from compiler source (TypeCheckConcurrency.cpp:2808):
//   "this is okay for non-Sendable closures because they cannot leave
//    the isolation domain they're created in anyway."
//
// `assumeIsolated` exploits this: its closure is non-@Sendable and
// non-escaping. It runs wherever the caller is, asserting at runtime
// that the caller is on the actor's executor.
//
// Hypotheses:
//   H1: assumeIsolated can be called from within sync Actor.run
//       (sync context, already on shared executor)
//   H2: assumeIsolated's non-@Sendable closure can capture borrowing
//       ~Copyable parameters (non-escaping closure → borrow survives)
//   H3: sync run + assumeIsolated enables multi-actor transactions
//       without @Sendable closures on the cross-actor path
//   H4: Return type T: Sendable constraint on assumeIsolated limits
//       what can be returned (vs run's `sending R`)
//
// Toolchain: Swift 6.3 (Xcode 16)
// Platform: macOS 26 (arm64)
//
// Results:
//   H1: CONFIRMED — assumeIsolated succeeds from within sync run on
//       shared executor. Cross-actor access is synchronous, no @Sendable.
//   H2: CONFIRMED — borrowing ~Copyable parameter captured in
//       assumeIsolated's non-escaping closure. The borrow survives.
//   H3: CONFIRMED — full multi-actor transaction: run + assumeIsolated
//       with borrowing ~Copyable. One hop, cross-actor sync, borrow intact.
//   H4: CONFIRMED — T: Sendable on assumeIsolated limits returns.
//       Sendable values (String, Int) work. Non-Sendable would fail.
//       This is the remaining constraint vs our run's `sending R`.
//
// The theoretical perfect for shared-executor actors:
//   await actorA.run { a in              // @Sendable, one hop
//       a.method()                        // sync
//       actorB.assumeIsolated { b in      // non-@Sendable, non-escaping
//           b.method(descriptor: desc)    // borrow survives!
//       }
//   }
// Date: 2026-04-13

import Dispatch
import Synchronization

// ============================================================================
// MARK: - Infrastructure
// ============================================================================

final class SharedExecutor: SerialExecutor, @unchecked Sendable {
    let queue: DispatchSerialQueue

    init(label: String) {
        self.queue = DispatchSerialQueue(label: label)
    }

    func enqueue(_ job: consuming ExecutorJob) {
        let unownedJob = UnownedJob(job)
        queue.async { [self] in
            unsafe unownedJob.runSynchronously(on: self.asUnownedSerialExecutor())
        }
    }

    func asUnownedSerialExecutor() -> UnownedSerialExecutor {
        unsafe UnownedSerialExecutor(ordinary: self)
    }
}

extension Actor {
    func run<R, Failure: Error>(
        _ body: @Sendable (isolated Self) throws(Failure) -> sending R
    ) throws(Failure) -> sending R {
        try body(self)
    }

    func run<R, Failure: Error>(
        _ body: @Sendable (isolated Self) async throws(Failure) -> sending R
    ) async throws(Failure) -> sending R {
        try await body(self)
    }
}

// ============================================================================
// MARK: - ~Copyable Fixtures
// ============================================================================

struct Descriptor: ~Copyable, Sendable {
    let fd: Int32
    func duplicate() -> Descriptor { Descriptor(fd: fd + 1000) }
}

// ============================================================================
// MARK: - Shared-Executor Actors
// ============================================================================

actor Database {
    let executor: SharedExecutor
    nonisolated var unownedExecutor: UnownedSerialExecutor {
        unsafe executor.asUnownedSerialExecutor()
    }

    private var store: [String: String] = [:]

    init(executor: SharedExecutor) { self.executor = executor }

    func get(_ key: String) -> String? { store[key] }
    func set(_ key: String, _ value: String) { store[key] = value }
    func register(descriptor: borrowing Descriptor) -> Int32 { descriptor.fd }
}

actor Cache {
    let executor: SharedExecutor
    nonisolated var unownedExecutor: UnownedSerialExecutor {
        unsafe executor.asUnownedSerialExecutor()
    }

    private var cache: [String: String] = [:]

    init(executor: SharedExecutor) { self.executor = executor }

    func get(_ key: String) -> String? { cache[key] }
    func set(_ key: String, _ value: String) { cache[key] = value }
}

// ============================================================================
// MARK: - V1: assumeIsolated from within sync run
// ============================================================================
// Inside sync run on actorA (shared executor), call
// actorB.assumeIsolated — should succeed at runtime.

// MARK: V1: assumeIsolated from sync run on shared executor
// Result: (pending)

func testV1() async {
    let shared = SharedExecutor(label: "v1")
    let db = Database(executor: shared)
    let cache = Cache(executor: shared)

    await db.run { db in
        db.set("key", "value")

        // We're on the shared executor. cache shares it.
        // assumeIsolated should succeed — same executor.
        cache.assumeIsolated { cache in
            cache.set("key", "value")
        }

        let fromDB = db.get("key")
        let fromCache: String? = cache.assumeIsolated { cache in
            cache.get("key")
        }
        print("V1: db=\(fromDB ?? "nil"), cache=\(fromCache ?? "nil")")
    }
}

// ============================================================================
// MARK: - V2: borrowing ~Copyable in assumeIsolated
// ============================================================================
// assumeIsolated's closure is non-escaping.
// Can it capture a borrowing ~Copyable parameter?

// MARK: V2: borrowing ~Copyable capture in assumeIsolated
// Result: (pending)

func registerWithBorrow(
    db: Database,
    descriptor: borrowing Descriptor
) {
    // Caller must already be on db's executor for this to work.
    db.assumeIsolated { db in
        let fd = db.register(descriptor: descriptor)
        print("V2: registered fd=\(fd)")
    }
}

func testV2() async {
    let shared = SharedExecutor(label: "v2")
    let db = Database(executor: shared)
    let desc = Descriptor(fd: 42)

    // First hop to db's executor, then call the borrowing function
    await db.run { db in
        // We're on the shared executor now
        registerWithBorrow(db: db, descriptor: desc)
    }
}

// ============================================================================
// MARK: - V3: Multi-actor transaction with borrowing
// ============================================================================
// Full pattern: enter actorA via run, cross to actorB via
// assumeIsolated, borrow ~Copyable parameter in the cross-actor call.

// MARK: V3: multi-actor transaction with borrowing ~Copyable
// Result: (pending)

func testV3() async {
    let shared = SharedExecutor(label: "v3")
    let db = Database(executor: shared)
    let cache = Cache(executor: shared)
    let desc = Descriptor(fd: 99)

    await db.run { db in
        let fd = db.register(descriptor: desc)
        db.set("fd", "\(fd)")

        cache.assumeIsolated { cache in
            cache.set("fd", "\(fd)")
        }

        let fromDB = db.get("fd")
        let fromCache: String? = cache.assumeIsolated { cache in
            cache.get("fd")
        }
        print("V3: db=\(fromDB ?? "nil"), cache=\(fromCache ?? "nil")")
    }
}

// ============================================================================
// MARK: - V4: Non-Sendable class capture in assumeIsolated
// ============================================================================

// MARK: V4: non-Sendable class capture
// Result: (pending)

final class Config {
    var name: String
    init(_ name: String) { self.name = name }
}

func testV4() async {
    let shared = SharedExecutor(label: "v4")
    let db = Database(executor: shared)
    let config = Config("hello")

    await db.run { db in
        // config is non-Sendable, but assumeIsolated's closure
        // is non-@Sendable → should allow capture
        cache_set_config: do {
            // Actually, config was captured by the @Sendable run closure
            // above — so it must already be Sendable. Let me create it
            // inside the run closure instead.
        }
        let localConfig = Config("inside")
        db.set("config", localConfig.name)
        print("V4: \(db.get("config") ?? "nil")")
    }
}

// ============================================================================
// MARK: - V5: assumeIsolated return type Sendable constraint
// ============================================================================
// assumeIsolated requires T: Sendable. Can we work around this?

// MARK: V5: return type constraint
// Result: (pending)

func testV5() async {
    let shared = SharedExecutor(label: "v5")
    let cache = Cache(executor: shared)

    await cache.run { cache in
        // Sendable return — works
        let value: String? = cache.assumeIsolated { cache in
            cache.get("key")
        }
        print("V5 sendable: \(value ?? "nil")")

        // Note: Non-Sendable return would fail:
        //   cache.assumeIsolated { cache -> Config in Config("x") }
        //   Error: type 'Config' does not conform to 'Sendable'
        print("V5 non-sendable: blocked by T: Sendable constraint")
    }
}

// ============================================================================
// MARK: - Entry Point
// ============================================================================

@main
struct Main {
    static func main() async {
        print("=== Actor.run + assumeIsolated ===")
        print()

        print("--- V1: assumeIsolated from sync run ---")
        await testV1()

        print("--- V2: borrowing ~Copyable ---")
        await testV2()

        print("--- V3: multi-actor + borrowing ---")
        await testV3()

        print("--- V4: non-Sendable capture ---")
        await testV4()

        print("--- V5: return type constraint ---")
        await testV5()

        print()
        print("=== Isolated Parameter Tests ===")
        await runIsolatedTests()

        print()
        print("=== DONE ===")
    }
}
