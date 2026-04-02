// MARK: - Detach + Exit Signal Validation
// Purpose: Verify that detached pthreads can safely signal exit via
//          Swift Concurrency primitives (CheckedContinuation, AsyncStream),
//          enabling fully non-blocking thread lifecycle in async contexts.
//
// Claims under test (from swift-io Research/perfect-lifecycle-design.md):
//   C1: A detached pthread can safely resume a CheckedContinuation as its
//       last action before the thread function returns
//   C2: Multiple independent exit signals complete without interference
//   C3: ~Copyable ~Escapable scope type can own detach + signal lifecycle
//   C4: deinit fires correctly when consuming close() async is not called
//   C5: N concurrent awaits complete in O(max_sleep), not O(N * max_sleep),
//       proving cooperative pool threads are free during await
//
// Toolchain: Apple Swift 6.3 (swiftlang-6.3.0.123.5)
// Platform: macOS 26 (arm64)
//
// Result: ALL CONFIRMED (6/6, debug + release)
//   V1: CONFIRMED — received 42 from detached pthread
//   V2: CONFIRMED — last-action resume delivered value
//   V3: CONFIRMED — all 10 signals received
//   V4a: CONFIRMED — close() path, deinit skipped emergency
//   V4b: CONFIRMED — deinit fired as emergency fallback
//   V5: CONFIRMED — 50 concurrent awaits in 106ms (debug) / 107ms (release)
//        (if blocked: ~833ms for 6 pool threads)
// Date: 2026-04-01

import Darwin

// ═══════════════════════════════════════════════════════════════════════
// Thread Infrastructure
// ═══════════════════════════════════════════════════════════════════════

/// C-compatible trampoline. Takes Unmanaged pointer to _Body, runs closure.
private func _trampoline(_ raw: UnsafeMutableRawPointer) -> UnsafeMutableRawPointer? {
    Unmanaged<_Body>.fromOpaque(raw).takeRetainedValue().work()
    return nil
}

private final class _Body: @unchecked Sendable {
    let work: @Sendable () -> Void
    init(_ work: @Sendable @escaping () -> Void) { self.work = work }
}

/// Spawn a detached OS thread running `body`. No join needed or possible.
func spawnDetached(_ body: @Sendable @escaping () -> Void) {
    let raw = Unmanaged.passRetained(_Body(body)).toOpaque()
    var tid: pthread_t?
    precondition(pthread_create(&tid, nil, _trampoline, raw) == 0)
    precondition(pthread_detach(tid!) == 0)
}

/// Convert Duration to milliseconds.
func ms(_ d: Duration) -> Int64 {
    let c = d.components
    return c.seconds * 1000 + c.attoseconds / 1_000_000_000_000_000
}

// ═══════════════════════════════════════════════════════════════════════
// MARK: - V1: Basic Exit Signal
// ═══════════════════════════════════════════════════════════════════════
// Hypothesis: A detached pthread can resume a CheckedContinuation,
//             and the awaiting task receives the value.
// Result: CONFIRMED — Output: 42

func v1() async {
    print("V1: Basic exit signal...")

    let value: Int = await withCheckedContinuation { continuation in
        spawnDetached {
            usleep(50_000) // 50ms of simulated work
            continuation.resume(returning: 42)
        }
    }

    precondition(value == 42, "V1 FAILED: expected 42, got \(value)")
    print("V1: CONFIRMED — received \(value) from detached pthread")
}

// ═══════════════════════════════════════════════════════════════════════
// MARK: - V2: Last-Action Guarantee
// ═══════════════════════════════════════════════════════════════════════
// Hypothesis: resume() works when it is literally the LAST statement
//             before the thread function returns — no work after resume.
// Result: CONFIRMED

func v2() async {
    print("\nV2: Last-action guarantee...")

    let ok: Bool = await withUnsafeContinuation { continuation in
        spawnDetached {
            let _ = 1 + 1 // all work done before signal
            continuation.resume(returning: true)
            // ← nothing here. function returns. thread exits.
        }
    }

    precondition(ok, "V2 FAILED: continuation not properly resumed")
    print("V2: CONFIRMED — last-action resume delivered value")
}

// ═══════════════════════════════════════════════════════════════════════
// MARK: - V3: Multiple Independent Signals
// ═══════════════════════════════════════════════════════════════════════
// Hypothesis: N detached pthreads with N independent continuations
//             all complete correctly without interference.
// Result: CONFIRMED — all 10 signals received: [0..9]

func v3() async {
    print("\nV3: 10 independent signals...")
    let n = 10

    let got = await withTaskGroup(of: Int.self, returning: Set<Int>.self) { group in
        for i in 0..<n {
            group.addTask {
                await withCheckedContinuation { c in
                    spawnDetached {
                        usleep(UInt32.random(in: 10_000...50_000))
                        c.resume(returning: i)
                    }
                }
            }
        }
        var s = Set<Int>()
        for await v in group { s.insert(v) }
        return s
    }

    precondition(got.count == n, "V3 FAILED: \(got.count)/\(n)")
    print("V3: CONFIRMED — all \(n) signals received: \(got.sorted())")
}

// ═══════════════════════════════════════════════════════════════════════
// MARK: - V4: Scope Pattern (~Copyable ~Escapable)
// ═══════════════════════════════════════════════════════════════════════
// Hypothesis: A ~Copyable ~Escapable struct can:
//   (a) Own an AsyncStream exit signal + spawn a detached thread in init
//   (b) Await the signal in consuming close() async
//   (c) Fire deinit when close() is not called
// Result: CONFIRMED (V4a: close path, V4b: deinit path)

nonisolated(unsafe) var _deinitFired = false

struct ThreadScope: ~Copyable, ~Escapable {
    private let stream: AsyncStream<Void>
    private var _closed: Bool

    @_lifetime(immortal)
    init(sleepUs: UInt32 = 50_000) {
        let (s, c) = AsyncStream.makeStream(of: Void.self)
        self.stream = s
        self._closed = false
        spawnDetached {
            usleep(sleepUs)
            c.yield(())
            c.finish()
        }
    }

    consuming func close() async {
        _closed = true
        for await _ in stream { break }
    }

    deinit {
        if _closed { return }
        _deinitFired = true
    }
}

func v4a() async {
    print("\nV4a: Scope — close() called...")
    _deinitFired = false

    let scope = ThreadScope(sleepUs: 30_000)
    await scope.close()

    // deinit runs after close() returns, but _closed is true → skip emergency
    precondition(!_deinitFired, "V4a FAILED: emergency deinit fired despite close()")
    print("V4a: CONFIRMED — close() completed, deinit skipped emergency path")
}

func v4b() async {
    print("\nV4b: Scope — deinit fires when close() not called...")
    _deinitFired = false

    do {
        let scope = ThreadScope(sleepUs: 50_000)
        // Intentionally not calling close()
        _ = consume scope // explicit discard → deinit fires
    }

    precondition(_deinitFired, "V4b FAILED: deinit did not fire")
    // Give the detached thread time to finish (it's still sleeping)
    usleep(100_000)
    print("V4b: CONFIRMED — deinit fired as emergency fallback")
}

// ═══════════════════════════════════════════════════════════════════════
// MARK: - V5: Concurrent Exit Signals (Non-Blocking Proof)
// ═══════════════════════════════════════════════════════════════════════
// Hypothesis: 50 detached pthreads sleeping 100ms each, with 50 tasks
//             awaiting concurrently, complete in ~100ms total.
//             If await blocked pool threads: ~50×100ms/6 ≈ 833ms.
// Result: CONFIRMED — 106ms debug, 107ms release (8x faster than blocked)

func v5() async {
    print("\nV5: 50 concurrent exit signals...")
    let n = 50
    let clock = ContinuousClock()
    let start = clock.now

    await withTaskGroup(of: Void.self) { group in
        for _ in 0..<n {
            group.addTask {
                await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
                    spawnDetached {
                        usleep(100_000) // 100ms
                        c.resume()
                    }
                }
            }
        }
    }

    let elapsed = ms(clock.now - start)

    // Non-blocking: ~100–200ms   Blocking: ~833ms for 6 pool threads
    precondition(elapsed < 500, "V5 FAILED: \(elapsed)ms — pool threads blocked")
    print("V5: CONFIRMED — \(n) concurrent awaits in \(elapsed)ms (non-blocking)")
    print("    (if blocked: ~\(n * 100 / 6)ms for 6 pool threads)")
}

// ═══════════════════════════════════════════════════════════════════════
// MARK: - Results Summary
// ═══════════════════════════════════════════════════════════════════════
// V1:  CONFIRMED — basic exit signal
// V2:  CONFIRMED — last-action resume
// V3:  CONFIRMED — 10 independent signals
// V4a: CONFIRMED — scope close() path
// V4b: CONFIRMED — scope deinit fallback
// V5:  CONFIRMED — 50 concurrent (non-blocking proof)

@main
enum Main {
    static func main() async {
        print("=== Detach + Exit Signal Validation ===\n")

        await v1()
        await v2()
        await v3()
        await v4a()
        await v4b()
        await v5()

        print("\n=== All variants complete ===")
    }
}
