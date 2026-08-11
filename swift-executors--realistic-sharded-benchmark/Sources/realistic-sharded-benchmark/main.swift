// MARK: - Realistic Sharded Benchmark
//
// Purpose:    Re-test cache-line padding on Sharded.cursor under a
//             workload that interleaves real compute between next()
//             calls. The cursor-padding-benchmark's V1 (tight-loop
//             next() with zero intervening work) showed padding is
//             neutral-to-negative because the cursor's line ping-
//             pongs regardless and Padded adds one pointer load.
//
//             Realistic Sharded callers do work between next()
//             calls. That work evicts cache lines. On the NEXT
//             next() call, both cursor AND neighbours (executors,
//             count) need to be re-fetched. In the unpadded layout,
//             cursor writes on other threads invalidate the shared
//             line — so the re-fetch is a full memory round-trip.
//             In the padded layout, the neighbour line stays quiet
//             (no writers), so re-fetching it is cheaper.
//
//             This benchmark sweeps compute-per-iteration to find
//             the crossover point (if any) where padded overtakes
//             unpadded.
//
// Hypothesis: There exists a compute-per-iteration threshold above
//             which padded Sharded.cursor outperforms unpadded.
//             Below that threshold, the tight-loop regime holds.
//
// Variants:
//   V1: Compute sweep — [10 ns, 100 ns, 1 µs, 10 µs] compute burn
//       between next() calls, 4 threads, 100k iterations each.
//       Identifies the crossover.
//
//   V2: Thread-scaling at fixed compute — 1 µs per iteration (a
//       plausible realistic per-actor workload), sweep 1/2/4/8
//       threads, measure throughput + padded vs unpadded delta.
//
// Toolchain:  Apple Swift 6.3
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
// Platform:   macOS 26.x (arm64)
// Build:      swift run -c release
//
// Date:       2026-04-17

import Darwin
import Synchronization
import CPU_Primitives

// ============================================================================
// MARK: - Cursor layouts (identical to cursor-padding-benchmark)
// ============================================================================

final class UnpaddedShardLike: @unchecked Sendable {
    let executors: [Int]
    let count: Int
    let cursor: Atomic<Int>

    init(count: Int) {
        self.executors = Array(0..<count)
        self.count = count
        self.cursor = .init(0)
    }

    @inline(never)
    func next() -> Int {
        let n = count
        while true {
            let current = cursor.load(ordering: .relaxed)
            let nextValue = (current + 1) % n
            let (exchanged, _) = cursor.compareExchange(
                expected: current,
                desired: nextValue,
                ordering: .relaxed
            )
            if exchanged { return executors[current] }
        }
    }
}

final class PaddedShardLike: @unchecked Sendable {
    let executors: [Int]
    let count: Int
    let cursor: CPU.Cache.Padded<Atomic<Int>>

    init(count: Int) {
        self.executors = Array(0..<count)
        self.count = count
        self.cursor = CPU.Cache.Padded<Atomic<Int>>(Atomic<Int>(0))
    }

    @inline(never)
    func next() -> Int {
        let n = count
        while true {
            let current = cursor.value.load(ordering: .relaxed)
            let nextValue = (current + 1) % n
            let (exchanged, _) = cursor.value.compareExchange(
                expected: current,
                desired: nextValue,
                ordering: .relaxed
            )
            if exchanged { return executors[current] }
        }
    }
}

// ============================================================================
// MARK: - Compute burn
// ============================================================================
//
// Calibrated below. Each call takes roughly `loops` iterations of a
// simple mix + store + load pattern. We also *touch* an unrelated
// heap buffer (`scratch`) to evict cache lines, which is the key
// difference from cursor-padding-benchmark's tight loop: between
// next() calls, the worker walks fresh memory, displacing any
// cached copy of the shard-object's class header.

/// Allocated once per worker. Total size chosen to exceed L1/L2 on
/// Apple Silicon so that walking it reliably evicts other lines.
/// 1 MiB is larger than per-core L1 (128 KiB data) and comparable
/// to per-core L2 on P cores (~12-16 MiB shared).
let scratchBytes = 1 << 20       // 1 MiB
let scratchCount = scratchBytes / MemoryLayout<Int>.stride

final class Scratch: @unchecked Sendable {
    let buffer: UnsafeMutablePointer<Int>
    var stride: Int = 0
    init() {
        buffer = UnsafeMutablePointer<Int>.allocate(capacity: scratchCount)
        buffer.initialize(repeating: 0, count: scratchCount)
    }
    deinit { buffer.deallocate() }
}

@inline(never)
func computeBurn(loops: Int, scratch: Scratch, counter: inout Int) {
    // Touch cache lines in scratch to evict non-hot memory from L1/L2.
    // Offset walking through the scratch buffer, 64-byte stride.
    let stride = 64 / MemoryLayout<Int>.stride
    var idx = counter % scratchCount
    for _ in 0..<loops {
        scratch.buffer[idx] = scratch.buffer[idx] &+ 1
        idx = (idx &+ stride) % scratchCount
    }
    counter = idx
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
// MARK: - Worker classes
// ============================================================================

final class UnpaddedMixedWorker: @unchecked Sendable {
    let gate: StartGate
    let pool: UnpaddedShardLike
    let iterations: Int
    let computeLoops: Int
    let scratch: Scratch
    var checksum: Int = 0

    init(gate: StartGate, pool: UnpaddedShardLike, iterations: Int, computeLoops: Int) {
        self.gate = gate
        self.pool = pool
        self.iterations = iterations
        self.computeLoops = computeLoops
        self.scratch = Scratch()
    }

    func run() {
        gate.workerArrive()
        var local = 0
        var scratchCounter = 0
        for _ in 0..<iterations {
            local &+= pool.next()
            computeBurn(loops: computeLoops, scratch: scratch, counter: &scratchCounter)
        }
        checksum = local
    }
}

final class PaddedMixedWorker: @unchecked Sendable {
    let gate: StartGate
    let pool: PaddedShardLike
    let iterations: Int
    let computeLoops: Int
    let scratch: Scratch
    var checksum: Int = 0

    init(gate: StartGate, pool: PaddedShardLike, iterations: Int, computeLoops: Int) {
        self.gate = gate
        self.pool = pool
        self.iterations = iterations
        self.computeLoops = computeLoops
        self.scratch = Scratch()
    }

    func run() {
        gate.workerArrive()
        var local = 0
        var scratchCounter = 0
        for _ in 0..<iterations {
            local &+= pool.next()
            computeBurn(loops: computeLoops, scratch: scratch, counter: &scratchCounter)
        }
        checksum = local
    }
}

func unpaddedEntry(_ arg: UnsafeMutableRawPointer) -> UnsafeMutableRawPointer? {
    let w = Unmanaged<UnpaddedMixedWorker>.fromOpaque(arg).takeRetainedValue()
    w.run()
    return nil
}

func paddedEntry(_ arg: UnsafeMutableRawPointer) -> UnsafeMutableRawPointer? {
    let w = Unmanaged<PaddedMixedWorker>.fromOpaque(arg).takeRetainedValue()
    w.run()
    return nil
}

// ============================================================================
// MARK: - Timing & formatting
// ============================================================================

func nanos(_ duration: Duration) -> Int64 {
    duration.components.seconds * 1_000_000_000
        + duration.components.attoseconds / 1_000_000_000
}

func formatDuration(_ duration: Duration) -> String {
    let ns = nanos(duration)
    if ns < 1_000 { return "\(ns) ns" }
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

func formatSpeedup(_ x: Double) -> String {
    let hundredths = Int(x * 100)
    let whole = hundredths / 100
    let frac = hundredths % 100
    let fracStr = frac < 10 ? "0\(frac)" : "\(frac)"
    return "\(whole).\(fracStr)x"
}

func padRight(_ s: String, _ width: Int) -> String {
    if s.count >= width { return s }
    return s + String(repeating: " ", count: width - s.count)
}

// ============================================================================
// MARK: - Calibrate compute-burn loops to target nanoseconds
// ============================================================================

/// Measure nanoseconds-per-loop for `computeBurn`, then invert to
/// pick a `loops` count that approximates `targetNs` per call.
func calibrateLoops(targetNs: Int) -> Int {
    let scratch = Scratch()
    let probeLoops = 10_000
    var counter = 0
    // Warm up
    computeBurn(loops: probeLoops, scratch: scratch, counter: &counter)

    let start = ContinuousClock.now
    let reps = 1000
    for _ in 0..<reps {
        computeBurn(loops: probeLoops, scratch: scratch, counter: &counter)
    }
    let elapsed = nanos(ContinuousClock.now - start)
    let nsPerLoop = Double(elapsed) / Double(reps * probeLoops)
    let loops = Int(Double(targetNs) / nsPerLoop)
    return max(1, loops)
}

// ============================================================================
// MARK: - V1: Compute sweep
// ============================================================================

func v1() {
    print("V1: Compute sweep (4 threads, 100k iterations each)")
    print("─────────────────────────────────────────────────────────────────────")
    print("\(padRight("target compute", 16))\(padRight("variant", 10))\(padRight("time", 14))speedup")
    print("─────────────────────────────────────────────────────────────────────")
    let iterations = 100_000
    let threadCount = 4
    let shardCount = 4

    let targetsNs = [10, 100, 1_000, 10_000]
    for targetNs in targetsNs {
        let computeLoops = calibrateLoops(targetNs: targetNs)

        // ---- Unpadded ----
        let unpaddedPool = UnpaddedShardLike(count: shardCount)
        let unpaddedGate = StartGate()
        var unpaddedThreads: [pthread_t] = []
        for _ in 0..<threadCount {
            let w = UnpaddedMixedWorker(
                gate: unpaddedGate, pool: unpaddedPool,
                iterations: iterations, computeLoops: computeLoops
            )
            var t: pthread_t?
            let rc = pthread_create(&t, nil, unpaddedEntry, Unmanaged.passRetained(w).toOpaque())
            precondition(rc == 0)
            unpaddedThreads.append(t!)
        }
        unpaddedGate.releaseWhenReady(expected: threadCount)
        let unpaddedStart = ContinuousClock.now
        for t in unpaddedThreads { pthread_join(t, nil) }
        let unpaddedElapsed = ContinuousClock.now - unpaddedStart

        // ---- Padded ----
        let paddedPool = PaddedShardLike(count: shardCount)
        let paddedGate = StartGate()
        var paddedThreads: [pthread_t] = []
        for _ in 0..<threadCount {
            let w = PaddedMixedWorker(
                gate: paddedGate, pool: paddedPool,
                iterations: iterations, computeLoops: computeLoops
            )
            var t: pthread_t?
            let rc = pthread_create(&t, nil, paddedEntry, Unmanaged.passRetained(w).toOpaque())
            precondition(rc == 0)
            paddedThreads.append(t!)
        }
        paddedGate.releaseWhenReady(expected: threadCount)
        let paddedStart = ContinuousClock.now
        for t in paddedThreads { pthread_join(t, nil) }
        let paddedElapsed = ContinuousClock.now - paddedStart

        let speedup = Double(nanos(unpaddedElapsed)) / Double(nanos(paddedElapsed))
        let label = "~\(targetNs) ns (L=\(computeLoops))"
        print("\(padRight(label, 16))\(padRight("unpadded", 10))\(padRight(formatDuration(unpaddedElapsed), 14))—")
        print("\(padRight(label, 16))\(padRight("padded", 10))\(padRight(formatDuration(paddedElapsed), 14))\(formatSpeedup(speedup))")
    }
    print("")
}

// ============================================================================
// MARK: - V2: Thread scaling at 1 µs compute
// ============================================================================

func v2() {
    print("V2: Thread scaling at ~1 µs compute/iteration (100k iter/thread)")
    print("─────────────────────────────────────────────────────────────────────")
    print("\(padRight("threads", 8))\(padRight("variant", 10))\(padRight("time", 14))speedup")
    print("─────────────────────────────────────────────────────────────────────")
    let iterations = 100_000
    let shardCount = 4
    let computeLoops = calibrateLoops(targetNs: 1_000)

    for threadCount in [1, 2, 4, 8] {
        // ---- Unpadded ----
        let unpaddedPool = UnpaddedShardLike(count: shardCount)
        let unpaddedGate = StartGate()
        var unpaddedThreads: [pthread_t] = []
        for _ in 0..<threadCount {
            let w = UnpaddedMixedWorker(
                gate: unpaddedGate, pool: unpaddedPool,
                iterations: iterations, computeLoops: computeLoops
            )
            var t: pthread_t?
            let rc = pthread_create(&t, nil, unpaddedEntry, Unmanaged.passRetained(w).toOpaque())
            precondition(rc == 0)
            unpaddedThreads.append(t!)
        }
        unpaddedGate.releaseWhenReady(expected: threadCount)
        let unpaddedStart = ContinuousClock.now
        for t in unpaddedThreads { pthread_join(t, nil) }
        let unpaddedElapsed = ContinuousClock.now - unpaddedStart

        // ---- Padded ----
        let paddedPool = PaddedShardLike(count: shardCount)
        let paddedGate = StartGate()
        var paddedThreads: [pthread_t] = []
        for _ in 0..<threadCount {
            let w = PaddedMixedWorker(
                gate: paddedGate, pool: paddedPool,
                iterations: iterations, computeLoops: computeLoops
            )
            var t: pthread_t?
            let rc = pthread_create(&t, nil, paddedEntry, Unmanaged.passRetained(w).toOpaque())
            precondition(rc == 0)
            paddedThreads.append(t!)
        }
        paddedGate.releaseWhenReady(expected: threadCount)
        let paddedStart = ContinuousClock.now
        for t in paddedThreads { pthread_join(t, nil) }
        let paddedElapsed = ContinuousClock.now - paddedStart

        let speedup = Double(nanos(unpaddedElapsed)) / Double(nanos(paddedElapsed))
        print("\(padRight("\(threadCount)", 8))\(padRight("unpadded", 10))\(padRight(formatDuration(unpaddedElapsed), 14))—")
        print("\(padRight("\(threadCount)", 8))\(padRight("padded", 10))\(padRight(formatDuration(paddedElapsed), 14))\(formatSpeedup(speedup))")
    }
    print("")
}

// ============================================================================
// MARK: - Driver
// ============================================================================

print("Realistic Sharded Benchmark (macOS arm64, 128-byte cache line)")
print("")
v1()
v2()
print("All variants completed.")
