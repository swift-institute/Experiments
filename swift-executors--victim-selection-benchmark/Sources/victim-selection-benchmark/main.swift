// MARK: - Victim-Selection Benchmark
//
// Purpose:    Compare sequential-scan vs XorShift32 random steal-
//             victim selection under skewed initial job placement.
//             Validates the DECISION in work-stealing-scheduler-design.md
//             Q2 (locked: random victim selection + XorShift32 PRNG
//             per worker) against the prior placeholder implementation.
//
// Hypothesis: Under skewed load (all jobs initially on one worker),
//             random victim selection distributes steal attempts
//             more uniformly across peer deques than sequential
//             scan, reducing lock contention on the victim and
//             improving total drain time.
//
// Harness:    Each variant simulates the Stealing.Worker run loop
//             with a lightweight mutex-protected deque (SimpleDeque)
//             in place of Chase-Lev. Job work is a tight 100 ns
//             burn (100 iterations of an atomic increment) so the
//             stealing overhead remains observable but doesn't
//             collapse into pure spinlock noise.
//
// Variants:
//   V1: Skewed initial load — 100k jobs placed on worker 0; drain.
//   V2: Even initial load — 25k jobs per worker; drain. Sanity
//       check that random is not catastrophically worse when load
//       starts balanced.
//
// Toolchain:  Apple Swift 6.3
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
// Platform:   macOS 26.x (arm64)
// Build:      swift run -c release
//
// Date:       2026-04-17

import Darwin
import Synchronization

// ============================================================================
// MARK: - Simple mutex-protected deque
// ============================================================================

/// Minimal thread-safe deque — not Chase-Lev, but good enough for the
/// benchmark. O(1) on both sides via index tracking; array backing
/// never mutates after init. Owner takes from the back (LIFO);
/// stealers take from the front (FIFO). Mutex-protected cursors.
final class SimpleDeque: @unchecked Sendable {
    private let lock = Mutex<Void>(())
    private let backing: [Int]
    private var takeCursor: Int    // owner's "top"; takes going down
    private var stealCursor: Int   // stealer's "bottom"; takes going up

    init(jobs: [Int]) {
        self.backing = jobs
        self.takeCursor = jobs.count
        self.stealCursor = 0
    }

    /// LIFO pop from the owner side. O(1).
    func take() -> Int? {
        lock.withLock { _ in
            if takeCursor <= stealCursor { return nil }
            takeCursor -= 1
            return backing[takeCursor]
        }
    }

    /// FIFO pop from the stealer side. O(1).
    func steal() -> Int? {
        lock.withLock { _ in
            if stealCursor >= takeCursor { return nil }
            let j = backing[stealCursor]
            stealCursor += 1
            return j
        }
    }

    var isEmpty: Bool {
        lock.withLock { _ in stealCursor >= takeCursor }
    }
}

// ============================================================================
// MARK: - Pool
// ============================================================================

final class Pool: @unchecked Sendable {
    let deques: [SimpleDeque]
    let shutdown = Atomic<Bool>(false)
    /// Workers that have drained both own + all peers — used to
    /// terminate when every worker has fully quiesced.
    let idle = Atomic<Int>(0)
    let totalWorkers: Int

    init(deques: [SimpleDeque]) {
        self.deques = deques
        self.totalWorkers = deques.count
    }
}

// ============================================================================
// MARK: - Workers (one class per variant — avoids Swift 6.3
//           SendNonSendable SIL crash on @Sendable closures through
//           @convention(c) pthread entries)
// ============================================================================

final class SequentialWorker: @unchecked Sendable {
    let gate: StartGate
    let pool: Pool
    let id: Int
    /// Consume-counter: how many jobs this worker completed (its own
    /// plus stolen). Written only from this worker's thread.
    var processed: Int = 0
    var stealAttempts: Int = 0
    var stealSuccesses: Int = 0

    init(gate: StartGate, pool: Pool, id: Int) {
        self.gate = gate
        self.pool = pool
        self.id = id
    }

    func run() {
        gate.workerArrive()
        let n = pool.deques.count
        let own = pool.deques[id]
        var consecutiveEmptyPasses = 0
        while !pool.shutdown.load(ordering: .acquiring) {
            if let job = own.take() {
                simulateWork(job)
                processed += 1
                consecutiveEmptyPasses = 0
                continue
            }
            // Sequential victim selection: deterministic neighbour-
            // first scan, matching the pre-XorShift32 behaviour.
            var stolen: Int? = nil
            for offset in 1..<n {
                let victim = (id + offset) % n
                stealAttempts += 1
                if let j = pool.deques[victim].steal() {
                    stolen = j
                    stealSuccesses += 1
                    break
                }
            }
            if let j = stolen {
                simulateWork(j)
                processed += 1
                consecutiveEmptyPasses = 0
                continue
            }
            // Empty drain — check global quiescence.
            consecutiveEmptyPasses += 1
            if consecutiveEmptyPasses > 100 {
                // Heuristic: if we can't find work 100 times in a
                // row, assume pool is drained.
                break
            }
        }
    }
}

final class RandomWorker: @unchecked Sendable {
    let gate: StartGate
    let pool: Pool
    let id: Int
    var processed: Int = 0
    var stealAttempts: Int = 0
    var stealSuccesses: Int = 0
    var rngState: UInt32

    init(gate: StartGate, pool: Pool, id: Int) {
        self.gate = gate
        self.pool = pool
        self.id = id
        self.rngState = UInt32(truncatingIfNeeded: id) &+ 0x9E3779B9
        if self.rngState == 0 { self.rngState = 1 }
    }

    private func nextRandom() -> UInt32 {
        rngState ^= rngState &<< 13
        rngState ^= rngState &>> 17
        rngState ^= rngState &<< 5
        return rngState
    }

    func run() {
        gate.workerArrive()
        let n = pool.deques.count
        let own = pool.deques[id]
        var consecutiveEmptyPasses = 0
        while !pool.shutdown.load(ordering: .acquiring) {
            if let job = own.take() {
                simulateWork(job)
                processed += 1
                consecutiveEmptyPasses = 0
                continue
            }
            // Random victim selection (XorShift32 per-worker).
            var stolen: Int? = nil
            if n > 1 {
                for _ in 0..<(n - 1) {
                    var victim = Int(nextRandom() % UInt32(n))
                    if victim == id { victim = (victim + 1) % n }
                    stealAttempts += 1
                    if let j = pool.deques[victim].steal() {
                        stolen = j
                        stealSuccesses += 1
                        break
                    }
                }
            }
            if let j = stolen {
                simulateWork(j)
                processed += 1
                consecutiveEmptyPasses = 0
                continue
            }
            consecutiveEmptyPasses += 1
            if consecutiveEmptyPasses > 100 { break }
        }
    }
}

/// Simulated work — does a bit of real compute so the stealing
/// overhead isn't the only thing being measured.
@inline(never)
func simulateWork(_ jobId: Int) {
    var x = jobId
    for _ in 0..<100 {
        x = x &+ 1
        x = x ^ (x &<< 3)
    }
    // Black-hole sink so the compiler can't elide the loop.
    _ = sideEffect(x)
}

nonisolated(unsafe) var sideEffectSink: Int = 0
@inline(never)
func sideEffect(_ x: Int) -> Int {
    sideEffectSink &+= x
    return sideEffectSink
}

// ============================================================================
// MARK: - Start gate
// ============================================================================

final class StartGate: @unchecked Sendable {
    let ready = Atomic<Int>(0)
    let go = Atomic<Bool>(false)

    func workerArrive() {
        _ = ready.wrappingAdd(1, ordering: .releasing)
        while !go.load(ordering: .acquiring) {}
    }

    func releaseWhenReady(expected: Int) {
        while ready.load(ordering: .acquiring) < expected {}
        go.store(true, ordering: .releasing)
    }
}

// ============================================================================
// MARK: - Entry functions
// ============================================================================

func sequentialEntry(_ arg: UnsafeMutableRawPointer) -> UnsafeMutableRawPointer? {
    let w = Unmanaged<SequentialWorker>.fromOpaque(arg).takeRetainedValue()
    w.run()
    return nil
}

func randomEntry(_ arg: UnsafeMutableRawPointer) -> UnsafeMutableRawPointer? {
    let w = Unmanaged<RandomWorker>.fromOpaque(arg).takeRetainedValue()
    w.run()
    return nil
}

// ============================================================================
// MARK: - Harness
// ============================================================================

struct RunResult {
    let elapsed: Duration
    let processedPerWorker: [Int]
    let stealAttempts: Int
    let stealSuccesses: Int
}

func runSequential(workerCount: Int, initialJobs: [[Int]]) -> RunResult {
    let deques = initialJobs.map { SimpleDeque(jobs: $0) }
    let pool = Pool(deques: deques)
    let gate = StartGate()
    var workers: [SequentialWorker] = []
    var threads: [pthread_t] = []
    for id in 0..<workerCount {
        let w = SequentialWorker(gate: gate, pool: pool, id: id)
        workers.append(w)
        var t: pthread_t?
        let rc = pthread_create(&t, nil, sequentialEntry, Unmanaged.passRetained(w).toOpaque())
        precondition(rc == 0)
        threads.append(t!)
    }
    gate.releaseWhenReady(expected: workerCount)
    let start = ContinuousClock.now
    for t in threads { pthread_join(t, nil) }
    let elapsed = ContinuousClock.now - start
    var totalAttempts = 0
    var totalSuccesses = 0
    let processed = workers.map { w -> Int in
        totalAttempts += w.stealAttempts
        totalSuccesses += w.stealSuccesses
        return w.processed
    }
    return RunResult(
        elapsed: elapsed,
        processedPerWorker: processed,
        stealAttempts: totalAttempts,
        stealSuccesses: totalSuccesses
    )
}

func runRandom(workerCount: Int, initialJobs: [[Int]]) -> RunResult {
    let deques = initialJobs.map { SimpleDeque(jobs: $0) }
    let pool = Pool(deques: deques)
    let gate = StartGate()
    var workers: [RandomWorker] = []
    var threads: [pthread_t] = []
    for id in 0..<workerCount {
        let w = RandomWorker(gate: gate, pool: pool, id: id)
        workers.append(w)
        var t: pthread_t?
        let rc = pthread_create(&t, nil, randomEntry, Unmanaged.passRetained(w).toOpaque())
        precondition(rc == 0)
        threads.append(t!)
    }
    gate.releaseWhenReady(expected: workerCount)
    let start = ContinuousClock.now
    for t in threads { pthread_join(t, nil) }
    let elapsed = ContinuousClock.now - start
    var totalAttempts = 0
    var totalSuccesses = 0
    let processed = workers.map { w -> Int in
        totalAttempts += w.stealAttempts
        totalSuccesses += w.stealSuccesses
        return w.processed
    }
    return RunResult(
        elapsed: elapsed,
        processedPerWorker: processed,
        stealAttempts: totalAttempts,
        stealSuccesses: totalSuccesses
    )
}

// ============================================================================
// MARK: - Formatting
// ============================================================================

func nanos(_ duration: Duration) -> Int64 {
    duration.components.seconds * 1_000_000_000
        + duration.components.attoseconds / 1_000_000_000
}

func formatDuration(_ duration: Duration) -> String {
    let ns = nanos(duration)
    if ns < 1_000_000 { return "\(ns / 1_000) µs" }
    if ns < 1_000_000_000 {
        let ms = ns / 1_000_000
        let tenths = (ns % 1_000_000) / 100_000
        return "\(ms).\(tenths) ms"
    }
    let s = ns / 1_000_000_000
    let ms = (ns % 1_000_000_000) / 1_000_000
    return "\(s).\(ms) s"
}

func formatPercent(_ num: Int, _ denom: Int) -> String {
    guard denom > 0 else { return "n/a" }
    let hundredths = num * 10_000 / denom
    let whole = hundredths / 100
    let frac = hundredths % 100
    let fracStr = frac < 10 ? "0\(frac)" : "\(frac)"
    return "\(whole).\(fracStr)%"
}

// ============================================================================
// MARK: - V1: Skewed initial load
// ============================================================================

func v1() {
    print("V1: Skewed load — 100k jobs on worker 0, 0 elsewhere")
    print("─────────────────────────────────────────────────────────────────────")
    print("    variant      time        steal-attempts  success-rate")
    print("─────────────────────────────────────────────────────────────────────")

    for workerCount in [4, 8] {
        let totalJobs = 100_000
        var initial: [[Int]] = []
        initial.append(Array(0..<totalJobs))       // worker 0 gets all
        for _ in 1..<workerCount {
            initial.append([])
        }

        let seq = runSequential(workerCount: workerCount, initialJobs: initial)
        let rnd = runRandom(workerCount: workerCount, initialJobs: initial)

        print("  \(workerCount)w sequential  \(formatDuration(seq.elapsed))     \(seq.stealAttempts)       \(formatPercent(seq.stealSuccesses, seq.stealAttempts))")
        print("  \(workerCount)w random      \(formatDuration(rnd.elapsed))     \(rnd.stealAttempts)       \(formatPercent(rnd.stealSuccesses, rnd.stealAttempts))")

        print("    sequential per-worker: \(seq.processedPerWorker)")
        print("    random     per-worker: \(rnd.processedPerWorker)")
    }
    print("")
}

// ============================================================================
// MARK: - V2: Even initial load
// ============================================================================

func v2() {
    print("V2: Even load — 25k jobs per worker initially")
    print("─────────────────────────────────────────────────────────────────────")

    for workerCount in [4, 8] {
        let jobsPerWorker = 25_000
        var initial: [[Int]] = []
        for i in 0..<workerCount {
            initial.append(Array((i * jobsPerWorker)..<((i + 1) * jobsPerWorker)))
        }

        let seq = runSequential(workerCount: workerCount, initialJobs: initial)
        let rnd = runRandom(workerCount: workerCount, initialJobs: initial)

        print("  \(workerCount)w sequential  \(formatDuration(seq.elapsed))")
        print("  \(workerCount)w random      \(formatDuration(rnd.elapsed))")

        print("    sequential steals: \(seq.stealAttempts) / successes: \(seq.stealSuccesses)")
        print("    random     steals: \(rnd.stealAttempts) / successes: \(rnd.stealSuccesses)")
    }
    print("")
}

// ============================================================================
// MARK: - Driver
// ============================================================================

print("Victim-Selection Benchmark (macOS arm64)")
print("")
v1()
v2()
print("All variants completed.")
