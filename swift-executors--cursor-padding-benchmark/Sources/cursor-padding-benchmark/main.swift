// MARK: - Cursor-Padding Benchmark
//
// Purpose:    Quantify the cache-line-padding benefit on a Sharded-
//             style cursor. Sharded.cursor is Atomic<Int>-equivalent
//             and co-located with read-mostly neighbours in the class
//             layout. Writes from N concurrent callers invalidate the
//             line containing those neighbours on every advance.
//
//             CPU.Cache.Padded<T> places the cursor in its own 128-
//             byte-aligned heap slot, eliminating that channel.
//
// Reference:  numa-aware-sharding.md Q1 (cache-line padding audit).
//             Research DECISION applied padding to Sharded.cursor.
//
// Variants:
//   V1: Contention scaling — 1/2/4/8 concurrent writers; each does M
//       next()-style calls; report wall-clock + ops/s + speedup.
//   V2: Per-call latency — 4 threads, record per-advance ns, report
//       P50 / P99 / P999 / max.
//
// Implementation note:
//   Swift 6.3 `SendNonSendable` SIL pass crashes when a `@Sendable`
//   closure flows through a function call that ends at a
//   `@convention(c)` pthread entry. Workaround: the thread runner is
//   not parameterized by a closure; instead two concrete Worker
//   classes (one per variant) implement `run()`. See main.swift
//   comment in scheduled-two-clock-spike for the same workaround.
//
// Toolchain:  Apple Swift 6.3
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
// Platform:   macOS 26.x (arm64) — 128-byte cache line
// Build:      swift run -c release
//
// Date:       2026-04-17

import Darwin
import Synchronization
import CPU_Primitives

// ============================================================================
// MARK: - Cursor layouts under test
// ============================================================================

/// Unpadded: cursor atomic co-located with read-mostly neighbours.
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

/// Padded: cursor atomic isolated in a 128-byte-aligned heap slot.
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
// MARK: - Start gate (replaces pthread_barrier; absent on Darwin)
// ============================================================================

final class StartGate: @unchecked Sendable {
    let ready = Atomic<Int>(0)
    let go = Atomic<Bool>(false)

    func workerArrive() {
        _ = ready.wrappingAdd(1, ordering: .releasing)
        while !go.load(ordering: .acquiring) {
            // spin
        }
    }

    func releaseWhenReady(expected: Int) {
        while ready.load(ordering: .acquiring) < expected {
            // spin
        }
        go.store(true, ordering: .releasing)
    }
}

// ============================================================================
// MARK: - Throughput workers
// ============================================================================

/// Worker for V1 unpadded throughput test. One instance per pthread.
final class UnpaddedWorker: @unchecked Sendable {
    let gate: StartGate
    let pool: UnpaddedShardLike
    let iterations: Int
    var checksum: Int = 0

    init(gate: StartGate, pool: UnpaddedShardLike, iterations: Int) {
        self.gate = gate
        self.pool = pool
        self.iterations = iterations
    }

    func run() {
        gate.workerArrive()
        var local = 0
        for _ in 0..<iterations {
            local &+= pool.next()
        }
        checksum = local
    }
}

/// Worker for V1 padded throughput test. Same shape as UnpaddedWorker.
final class PaddedWorker: @unchecked Sendable {
    let gate: StartGate
    let pool: PaddedShardLike
    let iterations: Int
    var checksum: Int = 0

    init(gate: StartGate, pool: PaddedShardLike, iterations: Int) {
        self.gate = gate
        self.pool = pool
        self.iterations = iterations
    }

    func run() {
        gate.workerArrive()
        var local = 0
        for _ in 0..<iterations {
            local &+= pool.next()
        }
        checksum = local
    }
}

func unpaddedEntry(_ arg: UnsafeMutableRawPointer) -> UnsafeMutableRawPointer? {
    let worker = Unmanaged<UnpaddedWorker>.fromOpaque(arg).takeRetainedValue()
    worker.run()
    return nil
}

func paddedEntry(_ arg: UnsafeMutableRawPointer) -> UnsafeMutableRawPointer? {
    let worker = Unmanaged<PaddedWorker>.fromOpaque(arg).takeRetainedValue()
    worker.run()
    return nil
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

func opsPerSec(calls: Int, duration: Duration) -> Double {
    Double(calls) / Double(nanos(duration)) * 1e9
}

func formatMOps(_ opsPerSec: Double) -> String {
    let mOps = Int(opsPerSec / 1e4)
    let whole = mOps / 100
    let frac = mOps % 100
    let fracStr = frac < 10 ? "0\(frac)" : "\(frac)"
    return "\(whole).\(fracStr) M/s"
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
// MARK: - V1: Contention scaling (throughput)
// ============================================================================

func v1() {
    print("V1: Contention scaling (4 shards, 1M next() per thread)")
    print("─────────────────────────────────────────────────────────────────────")
    print("\(padRight("threads", 8))\(padRight("variant", 10))\(padRight("time", 14))\(padRight("ops/s", 16))speedup")
    print("─────────────────────────────────────────────────────────────────────")
    let iterationsPerThread = 1_000_000
    let shardCount = 4

    for threadCount in [1, 2, 4, 8] {
        // ---- Unpadded ----
        let unpaddedPool = UnpaddedShardLike(count: shardCount)
        let unpaddedGate = StartGate()
        var unpaddedThreads: [pthread_t] = []
        var unpaddedWorkers: [UnpaddedWorker] = []
        for _ in 0..<threadCount {
            let w = UnpaddedWorker(
                gate: unpaddedGate, pool: unpaddedPool, iterations: iterationsPerThread
            )
            unpaddedWorkers.append(w)
            var t: pthread_t?
            let rc = pthread_create(&t, nil, unpaddedEntry, Unmanaged.passRetained(w).toOpaque())
            precondition(rc == 0)
            unpaddedThreads.append(t!)
        }
        unpaddedGate.releaseWhenReady(expected: threadCount)
        let unpaddedStart = ContinuousClock.now
        for t in unpaddedThreads { pthread_join(t, nil) }
        let unpaddedElapsed = ContinuousClock.now - unpaddedStart
        let unpaddedOps = opsPerSec(
            calls: iterationsPerThread * threadCount, duration: unpaddedElapsed
        )

        // ---- Padded ----
        let paddedPool = PaddedShardLike(count: shardCount)
        let paddedGate = StartGate()
        var paddedThreads: [pthread_t] = []
        var paddedWorkers: [PaddedWorker] = []
        for _ in 0..<threadCount {
            let w = PaddedWorker(
                gate: paddedGate, pool: paddedPool, iterations: iterationsPerThread
            )
            paddedWorkers.append(w)
            var t: pthread_t?
            let rc = pthread_create(&t, nil, paddedEntry, Unmanaged.passRetained(w).toOpaque())
            precondition(rc == 0)
            paddedThreads.append(t!)
        }
        paddedGate.releaseWhenReady(expected: threadCount)
        let paddedStart = ContinuousClock.now
        for t in paddedThreads { pthread_join(t, nil) }
        let paddedElapsed = ContinuousClock.now - paddedStart
        let paddedOps = opsPerSec(
            calls: iterationsPerThread * threadCount, duration: paddedElapsed
        )

        let speedup = paddedOps / unpaddedOps
        print("\(padRight("\(threadCount)", 8))\(padRight("unpadded", 10))\(padRight(formatDuration(unpaddedElapsed), 14))\(padRight(formatMOps(unpaddedOps), 16))—")
        print("\(padRight("\(threadCount)", 8))\(padRight("padded", 10))\(padRight(formatDuration(paddedElapsed), 14))\(padRight(formatMOps(paddedOps), 16))\(formatSpeedup(speedup))")
    }
    print("")
}

// ============================================================================
// MARK: - V2: Per-call latency
// ============================================================================

final class LatencyStore: @unchecked Sendable {
    let storage: UnsafeMutablePointer<UInt64>
    let count: Int
    init(count: Int) {
        self.count = count
        self.storage = UnsafeMutablePointer<UInt64>.allocate(capacity: count)
    }
    deinit { storage.deallocate() }
}

final class UnpaddedLatencyWorker: @unchecked Sendable {
    let gate: StartGate
    let pool: UnpaddedShardLike
    let store: LatencyStore
    let slot: Int
    let samples: Int
    var checksum: Int = 0

    init(gate: StartGate, pool: UnpaddedShardLike, store: LatencyStore, slot: Int, samples: Int) {
        self.gate = gate
        self.pool = pool
        self.store = store
        self.slot = slot
        self.samples = samples
    }

    func run() {
        gate.workerArrive()
        let base = slot * samples
        var local = 0
        for i in 0..<samples {
            let t0 = mach_absolute_time()
            local &+= pool.next()
            let t1 = mach_absolute_time()
            store.storage[base + i] = t1 &- t0
        }
        checksum = local
    }
}

final class PaddedLatencyWorker: @unchecked Sendable {
    let gate: StartGate
    let pool: PaddedShardLike
    let store: LatencyStore
    let slot: Int
    let samples: Int
    var checksum: Int = 0

    init(gate: StartGate, pool: PaddedShardLike, store: LatencyStore, slot: Int, samples: Int) {
        self.gate = gate
        self.pool = pool
        self.store = store
        self.slot = slot
        self.samples = samples
    }

    func run() {
        gate.workerArrive()
        let base = slot * samples
        var local = 0
        for i in 0..<samples {
            let t0 = mach_absolute_time()
            local &+= pool.next()
            let t1 = mach_absolute_time()
            store.storage[base + i] = t1 &- t0
        }
        checksum = local
    }
}

func unpaddedLatencyEntry(_ arg: UnsafeMutableRawPointer) -> UnsafeMutableRawPointer? {
    let worker = Unmanaged<UnpaddedLatencyWorker>.fromOpaque(arg).takeRetainedValue()
    worker.run()
    return nil
}

func paddedLatencyEntry(_ arg: UnsafeMutableRawPointer) -> UnsafeMutableRawPointer? {
    let worker = Unmanaged<PaddedLatencyWorker>.fromOpaque(arg).takeRetainedValue()
    worker.run()
    return nil
}

func v2() {
    print("V2: Per-call latency (4 threads, 100k samples/thread)")
    print("─────────────────────────────────────────────────────────────────────")
    let samplesPerThread = 100_000
    let threadCount = 4
    let shardCount = 4
    let totalSamples = samplesPerThread * threadCount

    var timebase = mach_timebase_info_data_t()
    mach_timebase_info(&timebase)
    let tbNumer = UInt64(timebase.numer)
    let tbDenom = UInt64(timebase.denom)

    func reportPercentiles(label: String, store: LatencyStore) {
        var arr = Array(UnsafeBufferPointer(start: store.storage, count: totalSamples))
        arr.sort()
        let toNs: (UInt64) -> UInt64 = { $0 * tbNumer / tbDenom }
        let p50 = toNs(arr[totalSamples / 2])
        let p99 = toNs(arr[Int(Double(totalSamples) * 0.99)])
        let p999 = toNs(arr[Int(Double(totalSamples) * 0.999)])
        let maxV = toNs(arr[totalSamples - 1])
        print("  \(padRight(label, 10))  P50 \(padRight("\(p50) ns", 10))  P99 \(padRight("\(p99) ns", 10))  P999 \(padRight("\(p999) ns", 12))  max \(maxV) ns")
    }

    // Unpadded
    let unpaddedPool = UnpaddedShardLike(count: shardCount)
    let unpaddedStore = LatencyStore(count: totalSamples)
    let unpaddedGate = StartGate()
    var unpaddedThreads: [pthread_t] = []
    for slot in 0..<threadCount {
        let w = UnpaddedLatencyWorker(
            gate: unpaddedGate, pool: unpaddedPool, store: unpaddedStore,
            slot: slot, samples: samplesPerThread
        )
        var t: pthread_t?
        let rc = pthread_create(&t, nil, unpaddedLatencyEntry, Unmanaged.passRetained(w).toOpaque())
        precondition(rc == 0)
        unpaddedThreads.append(t!)
    }
    unpaddedGate.releaseWhenReady(expected: threadCount)
    for t in unpaddedThreads { pthread_join(t, nil) }
    reportPercentiles(label: "unpadded", store: unpaddedStore)

    // Padded
    let paddedPool = PaddedShardLike(count: shardCount)
    let paddedStore = LatencyStore(count: totalSamples)
    let paddedGate = StartGate()
    var paddedThreads: [pthread_t] = []
    for slot in 0..<threadCount {
        let w = PaddedLatencyWorker(
            gate: paddedGate, pool: paddedPool, store: paddedStore,
            slot: slot, samples: samplesPerThread
        )
        var t: pthread_t?
        let rc = pthread_create(&t, nil, paddedLatencyEntry, Unmanaged.passRetained(w).toOpaque())
        precondition(rc == 0)
        paddedThreads.append(t!)
    }
    paddedGate.releaseWhenReady(expected: threadCount)
    for t in paddedThreads { pthread_join(t, nil) }
    reportPercentiles(label: "padded", store: paddedStore)
    print("")
}

// ============================================================================
// MARK: - V3: Classic false-sharing (independent per-thread atomics)
// ============================================================================
//
// V1 and V2 measure writes to a SHARED cursor — cache-line ping-pong on
// the cursor line dominates, and the primitive's indirection overhead
// can swamp the false-sharing benefit on the neighbour line.
//
// V3 isolates the false-sharing scenario cleanly: each thread has its
// own UInt64 counter. In the unpadded variant the counters are
// contiguous (false-share). In the padded variant each sits in its
// own CPU.Cache.Padded slot. No cross-thread writes to the same
// atomic; differences are attributable ONLY to cache-line sharing.

final class UnpaddedCounters: @unchecked Sendable {
    let storage: UnsafeMutablePointer<Atomic<UInt64>>
    let count: Int
    init(count: Int) {
        self.count = count
        storage = UnsafeMutablePointer<Atomic<UInt64>>.allocate(capacity: count)
        for i in 0..<count {
            (storage + i).initialize(to: Atomic<UInt64>(0))
        }
    }
    deinit {
        for i in 0..<count { (storage + i).deinitialize(count: 1) }
        storage.deallocate()
    }
}

final class PaddedCounters: @unchecked Sendable {
    // Box Padded<Atomic> in a class so we can index-access from Swift.
    // Each PaddedBox is heap-allocated; Padded<T> ensures 128-byte
    // alignment for its own Atomic slot.
    final class Slot: @unchecked Sendable {
        let value: CPU.Cache.Padded<Atomic<UInt64>>
        init() { value = CPU.Cache.Padded<Atomic<UInt64>>(Atomic<UInt64>(0)) }
    }
    let slots: [Slot]
    init(count: Int) {
        var s: [Slot] = []
        s.reserveCapacity(count)
        for _ in 0..<count { s.append(Slot()) }
        slots = s
    }
}

final class V3UnpaddedWorker: @unchecked Sendable {
    let gate: StartGate
    let counters: UnpaddedCounters
    let slot: Int
    let iterations: Int
    init(gate: StartGate, counters: UnpaddedCounters, slot: Int, iterations: Int) {
        self.gate = gate; self.counters = counters; self.slot = slot; self.iterations = iterations
    }
    func run() {
        gate.workerArrive()
        let p = counters.storage + slot
        for _ in 0..<iterations {
            _ = p.pointee.wrappingAdd(1, ordering: .relaxed)
        }
    }
}

final class V3PaddedWorker: @unchecked Sendable {
    let gate: StartGate
    let counters: PaddedCounters
    let slot: Int
    let iterations: Int
    init(gate: StartGate, counters: PaddedCounters, slot: Int, iterations: Int) {
        self.gate = gate; self.counters = counters; self.slot = slot; self.iterations = iterations
    }
    func run() {
        gate.workerArrive()
        let s = counters.slots[slot]
        for _ in 0..<iterations {
            _ = s.value.value.wrappingAdd(1, ordering: .relaxed)
        }
    }
}

func v3UnpaddedEntry(_ arg: UnsafeMutableRawPointer) -> UnsafeMutableRawPointer? {
    let w = Unmanaged<V3UnpaddedWorker>.fromOpaque(arg).takeRetainedValue()
    w.run()
    return nil
}

func v3PaddedEntry(_ arg: UnsafeMutableRawPointer) -> UnsafeMutableRawPointer? {
    let w = Unmanaged<V3PaddedWorker>.fromOpaque(arg).takeRetainedValue()
    w.run()
    return nil
}

func v3() {
    print("V3: Classic false-sharing (each thread writes own counter)")
    print("─────────────────────────────────────────────────────────────────────")
    print("\(padRight("threads", 8))\(padRight("variant", 10))\(padRight("time", 14))\(padRight("ops/s", 16))speedup")
    print("─────────────────────────────────────────────────────────────────────")
    let iterationsPerThread = 10_000_000

    for threadCount in [2, 4, 8] {
        // Unpadded (contiguous atomics)
        let unpadded = UnpaddedCounters(count: threadCount)
        let unpaddedGate = StartGate()
        var unpaddedThreads: [pthread_t] = []
        for slot in 0..<threadCount {
            let w = V3UnpaddedWorker(
                gate: unpaddedGate, counters: unpadded, slot: slot, iterations: iterationsPerThread
            )
            var t: pthread_t?
            let rc = pthread_create(&t, nil, v3UnpaddedEntry, Unmanaged.passRetained(w).toOpaque())
            precondition(rc == 0)
            unpaddedThreads.append(t!)
        }
        unpaddedGate.releaseWhenReady(expected: threadCount)
        let unpaddedStart = ContinuousClock.now
        for t in unpaddedThreads { pthread_join(t, nil) }
        let unpaddedElapsed = ContinuousClock.now - unpaddedStart
        let unpaddedOps = opsPerSec(
            calls: iterationsPerThread * threadCount, duration: unpaddedElapsed
        )

        // Padded (each atomic in own 128-byte line)
        let padded = PaddedCounters(count: threadCount)
        let paddedGate = StartGate()
        var paddedThreads: [pthread_t] = []
        for slot in 0..<threadCount {
            let w = V3PaddedWorker(
                gate: paddedGate, counters: padded, slot: slot, iterations: iterationsPerThread
            )
            var t: pthread_t?
            let rc = pthread_create(&t, nil, v3PaddedEntry, Unmanaged.passRetained(w).toOpaque())
            precondition(rc == 0)
            paddedThreads.append(t!)
        }
        paddedGate.releaseWhenReady(expected: threadCount)
        let paddedStart = ContinuousClock.now
        for t in paddedThreads { pthread_join(t, nil) }
        let paddedElapsed = ContinuousClock.now - paddedStart
        let paddedOps = opsPerSec(
            calls: iterationsPerThread * threadCount, duration: paddedElapsed
        )

        let speedup = paddedOps / unpaddedOps
        print("\(padRight("\(threadCount)", 8))\(padRight("unpadded", 10))\(padRight(formatDuration(unpaddedElapsed), 14))\(padRight(formatMOps(unpaddedOps), 16))—")
        print("\(padRight("\(threadCount)", 8))\(padRight("padded", 10))\(padRight(formatDuration(paddedElapsed), 14))\(padRight(formatMOps(paddedOps), 16))\(formatSpeedup(speedup))")
    }
    print("")
}

// ============================================================================
// MARK: - Driver
// ============================================================================

print("Cursor-Padding Benchmark  (macOS arm64, 128-byte cache line)")
print("")
v1()
v2()
v3()
print("All variants completed.")
