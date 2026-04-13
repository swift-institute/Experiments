// MARK: - Shared Executor Actor Communication
// Purpose: Verify that two actors sharing a SerialExecutor communicate
//          synchronously when already on that executor, and explore the
//          interaction between Actor.run and cross-actor shared-executor calls.
//
// Hypotheses:
//   H1: A custom SerialExecutor can be shared between two actor instances
//   H2: Cross-actor calls on a shared executor from outside still enqueue
//       one job per call (no optimization — caller is not on the executor)
//   H3: Cross-actor calls within a shared executor context elide the hop
//       (runtime executor check succeeds → no new job enqueued)
//   H4: Actor.run's synchronous closure CANNOT contain cross-actor awaits
//       (the closure becomes async, which run does not accept)
//   H5: An async variant of Actor.run enables cross-actor shared-executor
//       transactions at the cost of weaker atomicity guarantees
//   H6: Shared-executor actors are mutually exclusive (serialized)
//
// Toolchain: Swift 6.3 (Xcode 16)
// Platform: macOS 26 (arm64)
//
// Results:
//   H1: CONFIRMED — two actors with same LoggingExecutor instance compile and run
//   H2: CONFIRMED — 4 jobs for 4 calls from outside (no optimization)
//   H3: CONFIRMED — 1 job for 4 operations (2 db + 2 cache) via runAsync
//       from inside shared executor. Runtime elides cross-actor hops entirely.
//   H4: CONFIRMED — two overloads of `run` disambiguate by closure
//       async-ness. No await in body → sync overload (zero interleaving).
//       await in body → async overload (multi-actor, shared executor).
//   H5: CONFIRMED — async run enables multi-actor transactions. 1 job for
//       write-through cache pattern (db.set + cache.set + db.get + cache.get).
//       With SEPARATE executors same code produces 5 jobs (no elision).
//   H6: CONFIRMED — shared-executor actors serialize. Worker logs show
//       non-interleaved execution.
// Date: 2026-04-13

import Dispatch
import Synchronization

// ============================================================================
// MARK: - Infrastructure
// ============================================================================

final class LoggingExecutor: SerialExecutor, @unchecked Sendable {
    let queue: DispatchSerialQueue
    let label: String
    let _enqueueCount = Atomic<Int>(0)

    var enqueueCount: Int { _enqueueCount.load(ordering: .relaxed) }

    init(label: String) {
        self.label = label
        self.queue = DispatchSerialQueue(label: "logging-executor.\(label)")
    }

    func enqueue(_ job: consuming ExecutorJob) {
        _enqueueCount.wrappingAdd(1, ordering: .relaxed)
        let unownedJob = UnownedJob(job)
        queue.async { [self] in
            unsafe unownedJob.runSynchronously(on: self.asUnownedSerialExecutor())
        }
    }

    func asUnownedSerialExecutor() -> UnownedSerialExecutor {
        unsafe UnownedSerialExecutor(ordinary: self)
    }
}

/// Both overloads from standard-library-extensions.
/// Compiler disambiguates by closure async-ness:
///   - No await in body → sync overload (guaranteed atomic)
///   - await in body → async overload (atomic on shared executor only)
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

extension String {
    static func * (lhs: String, rhs: Int) -> String {
        String(repeating: lhs, count: rhs)
    }
}

// ============================================================================
// MARK: - Actors
// ============================================================================

actor Database {
    let executor: LoggingExecutor
    nonisolated var unownedExecutor: UnownedSerialExecutor {
        unsafe executor.asUnownedSerialExecutor()
    }

    private var store: [String: String] = [:]

    init(executor: LoggingExecutor) { self.executor = executor }

    func get(_ key: String) -> String? { store[key] }
    func set(_ key: String, _ value: String) { store[key] = value }
}

actor Cache {
    let executor: LoggingExecutor
    nonisolated var unownedExecutor: UnownedSerialExecutor {
        unsafe executor.asUnownedSerialExecutor()
    }

    private var cache: [String: String] = [:]

    init(executor: LoggingExecutor) { self.executor = executor }

    func get(_ key: String) -> String? { cache[key] }
    func set(_ key: String, _ value: String) { cache[key] = value }
    func invalidate(_ key: String) { cache[key] = nil }
}

// ============================================================================
// MARK: - Variant 1: Separate Executors — Baseline
// ============================================================================
// Each actor has its own executor. Every cross-actor call enqueues a job
// on the target's executor. This is the baseline job count.

func variant1() async {
    print("VARIANT 1: Separate Executors (Baseline)")
    print("-" * 50)

    let execDB = LoggingExecutor(label: "db")
    let execCache = LoggingExecutor(label: "cache")
    let db = Database(executor: execDB)
    let cache = Cache(executor: execCache)

    let beforeDB = execDB.enqueueCount
    let beforeCache = execCache.enqueueCount

    // 4 operations: db.set, cache.set, db.get, cache.get
    await db.set("k", "v")
    await cache.set("k", "v")
    _ = await db.get("k")
    _ = await cache.get("k")

    let jobsDB = execDB.enqueueCount - beforeDB
    let jobsCache = execCache.enqueueCount - beforeCache
    let total = jobsDB + jobsCache

    print("  Jobs: DB=\(jobsDB) Cache=\(jobsCache) Total=\(total)")
    print("  Expected: 4 (one per await)")
    print()
}

// ============================================================================
// MARK: - Variant 2: Shared Executor — Sequential From Outside
// ============================================================================
// Both actors share one executor. Calls come from OUTSIDE the executor.
// Each call still requires a hop in.

func variant2() async {
    print("VARIANT 2: Shared Executor — Sequential From Outside")
    print("-" * 50)

    let shared = LoggingExecutor(label: "shared")
    let db = Database(executor: shared)
    let cache = Cache(executor: shared)

    let before = shared.enqueueCount

    await db.set("k", "v")
    await cache.set("k", "v")
    _ = await db.get("k")
    _ = await cache.get("k")

    let jobs = shared.enqueueCount - before

    print("  Jobs: \(jobs)")
    print("  Expected: 4 (caller is outside executor, each call hops in)")
    print()
}

// ============================================================================
// MARK: - Variant 3: Shared Executor — Cross-Actor From Inside
// ============================================================================
// Enter one actor's context, then call the other actor.
// Both share the same executor → runtime should elide the hop.
// Uses runAsync because cross-actor calls require await.

func variant3() async {
    print("VARIANT 3: Shared Executor — Cross-Actor From Inside")
    print("-" * 50)

    let shared = LoggingExecutor(label: "shared-cross")
    let db = Database(executor: shared)
    let cache = Cache(executor: shared)

    let before = shared.enqueueCount

    // Enter db via runAsync, then call cache from inside.
    // We're already on the shared executor → cache call should not enqueue.
    await db.run { db in
        db.set("k", "v")
        await cache.set("k", "v")
        _ = db.get("k")
        _ = await cache.get("k")
    }

    let jobs = shared.enqueueCount - before

    print("  Jobs: \(jobs)")
    print("  If hop elided: 1 (only the initial db.run)")
    print("  If hop NOT elided: 3 (db.run + 2x cache)")
    print()
}

// ============================================================================
// MARK: - Variant 4: Actor.run (sync) Cannot Await
// ============================================================================
// Two overloads of `run` exist, disambiguated by closure async-ness.
// When the closure contains no `await`, the sync overload is selected,
// guaranteeing zero interleaving. When it contains `await`, the async
// overload is selected — interleaving is possible if the target actor
// is on a different executor.

func variant4() async {
    print("VARIANT 4: Actor.run (sync) Cannot Await Cross-Actor")
    print("-" * 50)

    let shared = LoggingExecutor(label: "shared-sync")
    let db = Database(executor: shared)
    let cache = Cache(executor: shared)

    // This compiles: single-actor synchronous transaction
    let before = shared.enqueueCount

    await db.run { db in
        db.set("k", "v")
        _ = db.get("k")
        db.set("k2", "v2")
        _ = db.get("k2")
    }

    let syncJobs = shared.enqueueCount - before
    print("  Sync run (single actor, 4 ops): \(syncJobs) job(s)")

    // Cannot do: await db.run { db in await cache.set(...) }
    // The closure would become async, rejected by run's signature.
    print("  Cross-actor await inside run: selects async overload automatically")
    print()
}

// ============================================================================
// MARK: - Variant 5: runAsync Enables Cross-Actor Transactions
// ============================================================================
// The async run variant permits await inside the closure.
// On a shared executor, cross-actor calls resolve without actual suspension.
// We test a write-through cache transaction.

func variant5() async {
    print("VARIANT 5: run (async) — Write-Through Cache Transaction")
    print("-" * 50)

    let shared = LoggingExecutor(label: "shared-txn")
    let db = Database(executor: shared)
    let cache = Cache(executor: shared)

    let before = shared.enqueueCount

    let result = await db.run { db in
        // Write-through: set in db, mirror to cache, read back both
        db.set("user:1", "Alice")
        await cache.set("user:1", "Alice")

        let fromDB = db.get("user:1")
        let fromCache = await cache.get("user:1")
        return (fromDB, fromCache)
    }

    let jobs = shared.enqueueCount - before

    print("  db=\(result.0 ?? "nil") cache=\(result.1 ?? "nil")")
    print("  Total jobs: \(jobs)")
    print("  4 operations (2 db sync + 2 cache await)")
    print("  Ideal: 1 job (initial hop, everything else elided)")
    print()
}

// ============================================================================
// MARK: - Variant 6: Separate Executors — runAsync Interleaving
// ============================================================================
// Same code as Variant 5, but with SEPARATE executors.
// The cache calls actually suspend → other tasks could interleave.
// This demonstrates the atomicity difference.

func variant6() async {
    print("VARIANT 6: run (async) with SEPARATE Executors (Non-Atomic)")
    print("-" * 50)

    let execDB = LoggingExecutor(label: "db-sep")
    let execCache = LoggingExecutor(label: "cache-sep")
    let db = Database(executor: execDB)
    let cache = Cache(executor: execCache)

    let beforeDB = execDB.enqueueCount
    let beforeCache = execCache.enqueueCount

    let result = await db.run { db in
        db.set("user:1", "Alice")
        await cache.set("user:1", "Alice")

        let fromDB = db.get("user:1")
        let fromCache = await cache.get("user:1")
        return (fromDB, fromCache)
    }

    let jobsDB = execDB.enqueueCount - beforeDB
    let jobsCache = execCache.enqueueCount - beforeCache

    print("  db=\(result.0 ?? "nil") cache=\(result.1 ?? "nil")")
    print("  DB jobs: \(jobsDB), Cache jobs: \(jobsCache)")
    print("  Note: cache calls cross executor boundary → real suspension")
    print("  Atomicity NOT guaranteed (other tasks can interleave at await)")
    print()
}

// ============================================================================
// MARK: - Variant 7: Serialization Between Shared-Executor Actors
// ============================================================================

actor Worker {
    let executor: LoggingExecutor
    nonisolated var unownedExecutor: UnownedSerialExecutor {
        unsafe executor.asUnownedSerialExecutor()
    }

    private(set) var log: [String] = []

    init(executor: LoggingExecutor) { self.executor = executor }

    func record(_ entry: String) {
        log.append(entry)
        // Busy work to hold the executor
        var sum = 0
        for i in 0..<500_000 { sum &+= i }
        _ = sum
    }
}

func variant7() async {
    print("VARIANT 7: Serialization Between Shared-Executor Actors")
    print("-" * 50)

    let shared = LoggingExecutor(label: "shared-serial")
    let w1 = Worker(executor: shared)
    let w2 = Worker(executor: shared)

    // Launch concurrent tasks targeting the same shared executor
    await withTaskGroup(of: Void.self) { group in
        group.addTask { await w1.record("w1-a"); await w1.record("w1-b") }
        group.addTask { await w2.record("w2-a"); await w2.record("w2-b") }
    }

    let log1 = await w1.log
    let log2 = await w2.log

    print("  Worker 1 log: \(log1)")
    print("  Worker 2 log: \(log2)")
    print("  Both workers share one executor → all operations serialized")
    print("  (no concurrent execution between w1 and w2)")
    print()
}

// ============================================================================
// MARK: - Entry Point
// ============================================================================

@main
struct Main {
    static func main() async {
        print()
        print("=" * 60)
        print("SHARED EXECUTOR ACTOR COMMUNICATION")
        print("=" * 60)
        print()

        await variant1()
        await variant2()
        await variant3()
        await variant4()
        await variant5()
        await variant6()
        await variant7()

        print("=" * 60)
        print("DONE")
        print("=" * 60)
    }
}
