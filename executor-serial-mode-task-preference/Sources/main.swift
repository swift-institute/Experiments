// MARK: - Executor Serial-Mode Task Preference
// Purpose: Verify whether withTaskExecutorPreference works with an executor
//   that reports serial identity (runSynchronously on asUnownedSerialExecutor)
//   vs task identity (runSynchronously on asUnownedTaskExecutor).
//
//   Context: swift-io executor-first-architecture research (Phase 2) needs
//   a single executor for both actor pinning (.serial mode — unownedExecutor)
//   and withTaskExecutorPreference (.task mode). If serial mode causes the
//   runtime to re-enqueue indefinitely, Phase 2 needs two executors or a
//   dual-mode executor.
//
// Toolchain: Apple Swift 6.3 (swiftlang-6.3.0.123.5)
// Platform: macOS 26.0 (arm64)
//
// Result: ALL CONFIRMED — serial mode works with withTaskExecutorPreference,
//   dual use (actor pinning + preference) works on a single executor,
//   async let inherits serial-mode preference, no deadlock on actor calls.
// Date: 2026-04-06

import Foundation // for pthread, Thread.current

// MARK: - Minimal Custom Executor

/// A minimal executor backed by a dedicated OS thread.
/// Supports both serial and task mode to test runtime identity routing.
final class TestExecutor: SerialExecutor, TaskExecutor, @unchecked Sendable {
    enum Mode: Sendable { case serial, task }

    let mode: Mode
    private let condition = NSCondition()
    private var jobs: [UnownedJob] = []
    private var isRunning = true
    private var _threadId: pthread_t?

    var threadId: pthread_t? { _threadId }

    init(mode: Mode) {
        self.mode = mode
        let t = Thread {
            self._threadId = pthread_self()
            self.runLoop()
        }
        t.start()
        // Brief yield to let the thread start and set threadId
        Thread.sleep(forTimeInterval: 0.01)
    }

    /// Check if the calling thread is this executor's thread.
    var isCurrent: Bool {
        guard let tid = _threadId else { return false }
        return pthread_equal(pthread_self(), tid) != 0
    }

    // MARK: SerialExecutor

    func enqueue(_ job: UnownedJob) {
        condition.lock()
        guard isRunning else {
            condition.unlock()
            switch mode {
            case .serial:
                unsafe job.runSynchronously(on: asUnownedSerialExecutor())
            case .task:
                unsafe job.runSynchronously(on: asUnownedTaskExecutor())
            }
            return
        }
        jobs.append(job)
        condition.signal()
        condition.unlock()
    }

    func asUnownedSerialExecutor() -> UnownedSerialExecutor {
        unsafe UnownedSerialExecutor(ordinary: self)
    }

    // MARK: TaskExecutor

    func enqueue(_ job: consuming ExecutorJob) {
        enqueue(UnownedJob(job))
    }

    // MARK: Run Loop

    private func runLoop() {
        while true {
            condition.lock()
            while jobs.isEmpty && isRunning {
                condition.wait()
            }
            guard isRunning || !jobs.isEmpty else {
                condition.unlock()
                return
            }
            let job = jobs.removeFirst()
            condition.unlock()

            switch mode {
            case .serial:
                unsafe job.runSynchronously(on: asUnownedSerialExecutor())
            case .task:
                unsafe job.runSynchronously(on: asUnownedTaskExecutor())
            }
        }
    }

    // MARK: Shutdown

    func shutdown() {
        condition.lock()
        isRunning = false
        condition.broadcast()
        condition.unlock()
        Thread.sleep(forTimeInterval: 0.05)
    }
}

// MARK: - Test Actor

/// Actor pinned to a custom executor via unownedExecutor.
actor PinnedActor {
    let executor: TestExecutor
    nonisolated var unownedExecutor: UnownedSerialExecutor {
        executor.asUnownedSerialExecutor()
    }

    init(executor: TestExecutor) {
        self.executor = executor
    }

    func runningOnExecutor() -> Bool {
        executor.isCurrent
    }

    func getValue() -> Int { 42 }
}

// MARK: - Timeout helper

/// Runs `body` with a timeout. Returns `nil` if timed out.
func withTimeout<T: Sendable>(
    seconds: Int,
    body: @Sendable @escaping () async -> T
) async -> T? {
    await withTaskGroup(of: T?.self) { group in
        group.addTask { await body() }
        group.addTask {
            try? await Task.sleep(for: .seconds(seconds))
            return nil
        }
        let first = await group.next()!
        group.cancelAll()
        return first
    }
}

// MARK: - V1: withTaskExecutorPreference with TASK mode
// Hypothesis: withTaskExecutorPreference works with .task mode executor
//   (runSynchronously on asUnownedTaskExecutor). Known-working baseline.
// Result: CONFIRMED — isCurrent = true

func testV1() async {
    print("--- V1: Task mode + withTaskExecutorPreference ---")
    let executor = TestExecutor(mode: .task)
    defer { executor.shutdown() }

    let onExecutor: Bool = await withTaskExecutorPreference(executor) {
        let result = executor.isCurrent
        print("  Inside preference: isCurrent = \(result)")
        return result
    }
    print("  Result: \(onExecutor ? "CONFIRMED" : "REFUTED")")
}

// MARK: - V2: withTaskExecutorPreference with SERIAL mode
// Hypothesis: withTaskExecutorPreference works with .serial mode executor
//   (runSynchronously on asUnownedSerialExecutor). If the runtime requires
//   task identity for preference routing, this will hang or re-enqueue forever.
// Result: CONFIRMED — isCurrent = true, no re-enqueue

func testV2() async {
    print("--- V2: Serial mode + withTaskExecutorPreference ---")
    let executor = TestExecutor(mode: .serial)
    defer { executor.shutdown() }

    let result: Bool? = await withTimeout(seconds: 3) {
        await withTaskExecutorPreference(executor) {
            let onExec = executor.isCurrent
            print("  Inside preference: isCurrent = \(onExec)")
            return onExec
        }
    }

    switch result {
    case .some(true):
        print("  Result: CONFIRMED — serial mode works with preference")
    case .some(false):
        print("  Result: REFUTED — ran but not on executor thread")
    case .none:
        print("  Result: REFUTED — timed out (likely infinite re-enqueue)")
    }
}

// MARK: - V3: Actor pinning + withTaskExecutorPreference on SAME serial executor
// Hypothesis: A single serial-mode executor can be used for both actor pinning
//   (unownedExecutor) and withTaskExecutorPreference simultaneously.
// Result: CONFIRMED — both actor method and preference run on executor thread

func testV3() async {
    print("--- V3: Dual use — actor pinning + preference (serial mode) ---")
    let executor = TestExecutor(mode: .serial)
    defer { executor.shutdown() }

    let actor = PinnedActor(executor: executor)

    // First: verify actor runs on executor
    let actorOnExecutor = await actor.runningOnExecutor()
    print("  Actor method runs on executor: \(actorOnExecutor)")

    // Second: verify withTaskExecutorPreference runs on same executor
    let prefResult: Bool? = await withTimeout(seconds: 3) {
        await withTaskExecutorPreference(executor) {
            let onExec = executor.isCurrent
            print("  Preference runs on executor: \(onExec)")
            return onExec
        }
    }

    let prefOnExecutor = prefResult == true
    if actorOnExecutor && prefOnExecutor {
        print("  Result: CONFIRMED — dual use works")
    } else if prefResult == nil {
        print("  Result: REFUTED — preference timed out")
    } else {
        print("  Result: REFUTED — actor=\(actorOnExecutor), pref=\(prefOnExecutor)")
    }
}

// MARK: - V4: async let inside withTaskExecutorPreference with serial-mode executor
// Hypothesis: async let child tasks inherit executor preference when the
//   executor is in serial mode. This is the Phase 1+2 combined pattern.
// Result: CONFIRMED — both parent and child run on executor thread

func testV4() async {
    print("--- V4: async let inside preference (serial mode) ---")
    let executor = TestExecutor(mode: .serial)
    defer { executor.shutdown() }

    let result: (Bool, Bool)? = await withTimeout(seconds: 3) {
        await withTaskExecutorPreference(executor) {
            let parentOnExec = executor.isCurrent
            async let childOnExec: Bool = {
                let onExec = executor.isCurrent
                print("  Child task on executor: \(onExec)")
                return onExec
            }()
            let childResult = await childOnExec
            print("  Parent on executor: \(parentOnExec)")
            return (parentOnExec, childResult)
        }
    }

    switch result {
    case .some((true, true)):
        print("  Result: CONFIRMED — async let inherits serial-mode preference")
    case .some(let (p, c)):
        print("  Result: REFUTED — parent=\(p), child=\(c)")
    case .none:
        print("  Result: REFUTED — timed out")
    }
}

// MARK: - V5: Actor method call from within withTaskExecutorPreference
// Hypothesis: Calling an actor method (pinned to the same serial-mode executor)
//   from within withTaskExecutorPreference does not deadlock. Since both the
//   caller and the actor are on the same serial executor, the runtime should
//   detect same-executor and run inline.
// Result: CONFIRMED — no deadlock, actor returned 42

func testV5() async {
    print("--- V5: Actor call from within preference (same executor) ---")
    let executor = TestExecutor(mode: .serial)
    defer { executor.shutdown() }

    let actor = PinnedActor(executor: executor)

    let result: Int? = await withTimeout(seconds: 3) {
        await withTaskExecutorPreference(executor) {
            let value = await actor.getValue()
            print("  Actor returned \(value) from within preference")
            return value
        }
    }

    switch result {
    case .some(42):
        print("  Result: CONFIRMED — no deadlock, actor call works")
    case .some(let v):
        print("  Result: UNEXPECTED — actor returned \(v)")
    case .none:
        print("  Result: REFUTED — deadlock or timeout")
    }
}

// MARK: - Run All

await testV1()
print()
await testV2()
print()
await testV3()
print()
await testV4()
print()
await testV5()

// MARK: - Results Summary
// V1: CONFIRMED — baseline: task mode + withTaskExecutorPreference
// V2: CONFIRMED — serial mode + withTaskExecutorPreference
// V3: CONFIRMED — dual use: actor pinning + preference on same serial executor
// V4: CONFIRMED — async let inherits serial-mode preference
// V5: CONFIRMED — actor call from within preference (same executor, no deadlock)
