// MARK: - Actor State Cross-Thread Inline Visibility
// Purpose: Verify or refute that an actor's stored state is read as STALE
//          when an actor method runs via runSynchronously on a thread that is
//          NOT the actor's executor thread (i.e., the inline-fallback path of
//          a custom executor whose run loop has exited).
//
// Context: swift-io has a custom executor (IO.Event.Loop) whose `enqueue()`
//          falls back to `runSynchronously(on:)` when the run loop has exited.
//          The Runtime actor pinned to this executor sets `state = .shuttingDown`
//          on the executor thread, then exits its run loop. A subsequent call
//          to `runtime.register()` from the test thread enters the inline
//          fallback, runs the actor method on the test thread, and reads
//          `state` as `.running` (stale) — but only in release mode.
//
// Hypothesis: Either
//   H1: Memory-ordering bug in the Synchronization primitive (release-mode
//       reordering of the actor's state load above the lock acquire). FALSIFIABLE.
//   H2: pthread_join provides happens-before but Swift's continuation-resume
//       handoff loses it for actor-isolated state loads. FALSIFIABLE.
//   H3: The compiler treats actor-isolated `var` reads as race-free and so
//       doesn't insert the necessary load fence at the actor method entry.
//       Means stale reads are not a memory-ordering accident — they are a
//       direct consequence of bypassing the executor-imposed serialization.
//   H4: The bug is unrelated to memory ordering — e.g., the actor method is
//       running on a different actor instance (impossible here, single instance)
//       or the test scenario in swift-io triggers a different code path.
//
// Experiments:
//   V1: Baseline — actor on dedicated executor, write state on executor thread,
//       run loop exits, then enqueue from main thread → inline fallback → read state.
//       Should reproduce bug if H1/H2/H3 hold.
//   V2: Same as V1 but read `state` via an explicit @inline(never) function.
//       Forces the load to be a real memory access, no caching. Tests H3.
//   V3: Add a manual atomic flag (separate from actor state) read on the same
//       path. If the atomic shows .shuttingDown but the actor state shows
//       .running, that proves the bug is specific to actor-isolated storage.
//   V4: Loop the read 1000 times under N iterations to verify the bug is
//       deterministic, not a coin flip.
//
// Toolchain: Swift 6.3 (Xcode 26 beta) — must run with `-c release`
// Platform:  macOS 26 (arm64)
// Date:      2026-04-07

import Synchronization

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

// ============================================================================
// MARK: - Minimal Mutex (pthread)
// ============================================================================

final class Mutex: @unchecked Sendable {
    private var m = pthread_mutex_t()
    init() { pthread_mutex_init(&m, nil) }
    deinit { pthread_mutex_destroy(&m) }
    func lock() { pthread_mutex_lock(&m) }
    func unlock() { pthread_mutex_unlock(&m) }
    func withLock<R>(_ body: () -> R) -> R {
        lock(); defer { unlock() }
        return body()
    }
}

final class Condition: @unchecked Sendable {
    private var c = pthread_cond_t()
    init() { pthread_cond_init(&c, nil) }
    deinit { pthread_cond_destroy(&c) }
    func wait(_ mutex: Mutex) {
        // Reach into Mutex's pthread_mutex_t — leave as a hack for the experiment.
        withUnsafePointer(to: &c) { cp in
            mutex.lock()  // already held by caller; pthread_cond_wait expects locked
            mutex.unlock()
            // Use a polling spin instead — we don't actually need cv signaling for this experiment
        }
    }
    func signal() { pthread_cond_signal(&c) }
    func broadcast() { pthread_cond_broadcast(&c) }
}

// ============================================================================
// MARK: - Custom Serial Executor with inline-fallback
// ============================================================================

final class TestLoop: SerialExecutor, @unchecked Sendable {
    private let mutex = Mutex()
    private var jobs: [UnownedJob] = []
    private var isRunning: Bool = true
    nonisolated(unsafe) private var thread: pthread_t? = nil

    init() {
        // Spawn a dedicated thread that drains jobs until isRunning becomes false.
        let opaque = Unmanaged.passRetained(self).toOpaque()
        var attr = pthread_attr_t()
        pthread_attr_init(&attr)
        var t: pthread_t? = nil
        pthread_create(&t, &attr, { argptr in
            let me = Unmanaged<TestLoop>.fromOpaque(argptr).takeRetainedValue()
            me.runLoop()
            return nil
        }, opaque)
        pthread_attr_destroy(&attr)
        self.thread = t
    }

    func runLoop() {
        while true {
            let batch = takeBatch()
            if batch.isEmpty {
                let stop = mutex.withLock { !self.isRunning }
                if stop { break }
                usleep(100)
                continue
            }
            for job in batch {
                unsafe job.runSynchronously(on: asUnownedSerialExecutor())
            }
        }
        // Final drain
        let final = takeBatch()
        for job in final {
            unsafe job.runSynchronously(on: asUnownedSerialExecutor())
        }
    }

    private func takeBatch() -> [UnownedJob] {
        mutex.lock(); defer { mutex.unlock() }
        let result = jobs
        jobs = []
        return result
    }

    func enqueue(_ job: UnownedJob) {
        let runInline: Bool = mutex.withLock {
            if !isRunning {
                return true
            }
            jobs.append(job)
            return false
        }
        if runInline {
            unsafe job.runSynchronously(on: asUnownedSerialExecutor())
        }
    }

    func asUnownedSerialExecutor() -> UnownedSerialExecutor {
        unsafe UnownedSerialExecutor(ordinary: self)
    }

    /// Signal the run loop to exit and join the thread.
    func shutdown() {
        mutex.withLock { self.isRunning = false }
        var ignored: UnsafeMutableRawPointer? = nil
        if let t = thread {
            pthread_join(t, &ignored)
        }
    }
}

// ============================================================================
// MARK: - Actor pinned to TestLoop
// ============================================================================

actor Runtime {
    let executor: TestLoop

    enum State { case running, shuttingDown }
    private var state: State = .running

    /// Atomic mirror of state for cross-validation. If state == .shuttingDown
    /// is invisible but mirror.load(.acquiring) shows the same write, that
    /// confirms the issue is actor-isolated storage specifically.
    let mirror = Atomic<UInt8>(0)  // 0 = running, 1 = shuttingDown

    init(executor: TestLoop) {
        self.executor = executor
    }

    nonisolated var unownedExecutor: UnownedSerialExecutor {
        executor.asUnownedSerialExecutor()
    }

    func setShuttingDown() {
        state = .shuttingDown
        mirror.store(1, ordering: .releasing)
    }

    /// Reads state and returns (actorState, mirrorState).
    /// Should always be (.shuttingDown, 1) after setShuttingDown() has run.
    @inline(never)
    func observe() -> (Bool, Bool) {
        let s = (state == .shuttingDown)
        let m = (mirror.load(ordering: .acquiring) == 1)
        return (s, m)
    }

    struct ShutdownInProgress: Error {}
    struct SideEffectError: Error {}

    /// Mimics swift-io's Runtime.register: read state and throw if shutting down.
    func register() throws -> String {
        guard state == .running else {
            throw ShutdownInProgress()
        }
        return "registered"
    }

    /// Mimics Runtime.shutdown(): set state, set halt flag, return.
    func shutdownLikeSwiftIO() {
        guard state == .running else { return }
        state = .shuttingDown
        // (mirror is updated for cross-validation)
        mirror.store(1, ordering: .releasing)
    }

    /// Mimics Runtime.register: state check + dup attempt that always fails.
    func registerLikeSwiftIO() throws -> String {
        guard state == .running else { throw ShutdownInProgress() }
        return "registered"
    }

    /// Mimics Runtime.register with a side-effect after the state check.
    func registerWithSideEffect() throws -> String {
        guard state == .running else { throw ShutdownInProgress() }
        // Side effect that always fails — mimics dup() failure on -1
        throw SideEffectError()
    }
}

// ============================================================================
// MARK: - Experiments
// ============================================================================

@main struct Main {
    static func main() async {
        print("=== Actor state cross-thread inline visibility experiment ===")
        print("")

        await V1_baseline()
        await V2_atomicMirror()
        await V3_loop(iterations: 1000)
        await V4_swiftIoMimic()
        await V5_dupAfterStateCheck()
    }

    /// V4: Mimic swift-io's exact two-actor-method-call pattern.
    /// shutdown() then register() in sequence, register() reads state.
    static func V4_swiftIoMimic() async {
        print("\n--- V4: swift-io two-call mimic ---")
        let loop = TestLoop()
        let runtime = Runtime(executor: loop)
        try? await Task.sleep(nanoseconds: 10_000_000)
        // Mimic Runtime.shutdown() — set state, set halt flag
        await runtime.shutdownLikeSwiftIO()
        // Synchronous join
        loop.shutdown()
        // Now call register() — inline fallback
        do {
            _ = try await runtime.registerLikeSwiftIO()
            print("V4 BUG REPRODUCED: register threw nothing (state == .running)")
        } catch is Runtime.ShutdownInProgress {
            print("V4: register threw shutdownInProgress (state visible)")
        } catch {
            print("V4: register threw \(error)")
        }
    }

    /// V5: Check if dup-after-state-check fails to throw shutdownInProgress.
    /// Simulates the case where a SIDE EFFECT happens after the state check
    /// and is observed instead of the throw.
    static func V5_dupAfterStateCheck() async {
        print("\n--- V5: side-effect after state check ---")
        let loop = TestLoop()
        let runtime = Runtime(executor: loop)
        try? await Task.sleep(nanoseconds: 10_000_000)
        await runtime.shutdownLikeSwiftIO()
        loop.shutdown()
        do {
            _ = try await runtime.registerWithSideEffect()
            print("V5: side-effect path returned (no throw)")
        } catch is Runtime.ShutdownInProgress {
            print("V5: state check threw shutdownInProgress")
        } catch is Runtime.SideEffectError {
            print("V5 BUG REPRODUCED: side-effect ran (state check passed when it shouldn't)")
        } catch {
            print("V5: \(error)")
        }
    }

    /// V1: Reproduce the swift-io pattern.
    static func V1_baseline() async {
        print("--- V1: baseline ---")
        let loop = TestLoop()
        let runtime = Runtime(executor: loop)

        // Let the run loop start
        try? await Task.sleep(nanoseconds: 10_000_000)

        // Set the state via an actor method (runs on executor thread).
        await runtime.setShuttingDown()

        // Shut down the executor's run loop and join its thread.
        loop.shutdown()

        // Now call register() — the actor method runs via inline fallback
        // on the calling thread.
        do {
            let result = try await runtime.register()
            print("V1 BUG REPRODUCED: register() returned \"\(result)\" instead of throwing")
            print("    The actor state was observed as .running (stale)")
        } catch {
            print("V1: register() threw correctly (state was visible as .shuttingDown)")
        }
    }

    /// V2: Compare actor state read against an Atomic mirror, on the same path.
    static func V2_atomicMirror() async {
        print("\n--- V2: atomic mirror ---")
        let loop = TestLoop()
        let runtime = Runtime(executor: loop)

        try? await Task.sleep(nanoseconds: 10_000_000)
        await runtime.setShuttingDown()
        loop.shutdown()

        let (actorVisible, mirrorVisible) = await runtime.observe()
        print("V2: actor state visible as .shuttingDown? \(actorVisible)")
        print("V2: atomic mirror visible as .shuttingDown? \(mirrorVisible)")
        if actorVisible != mirrorVisible {
            print("V2 DIVERGENCE: atomic and actor-state see different values")
        }
    }

    /// V3: Run V1 N times to determine if the bug is deterministic.
    static func V3_loop(iterations: Int) async {
        print("\n--- V3: \(iterations) iterations ---")
        var bugCount = 0
        var correctCount = 0
        for _ in 0..<iterations {
            let loop = TestLoop()
            let runtime = Runtime(executor: loop)
            try? await Task.sleep(nanoseconds: 1_000_000)
            await runtime.setShuttingDown()
            loop.shutdown()
            do {
                _ = try await runtime.register()
                bugCount += 1
            } catch {
                correctCount += 1
            }
        }
        print("V3: \(bugCount) bug observations, \(correctCount) correct out of \(iterations)")
    }
}
