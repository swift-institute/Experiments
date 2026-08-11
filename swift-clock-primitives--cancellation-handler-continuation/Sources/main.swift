// MARK: - CheckedContinuation<Void, Never> + Task.immediate (no existentials)
// Purpose: Verify that withCheckedContinuation<Void, Never> (no withTaskCancellationHandler)
//          provides deterministic registration with Task.immediate.
//          Cancellation is polled via try Task.checkCancellation() after wake;
//          cancelled tasks require run()/advance() to unpark.
//
// Background: withTaskCancellationHandler was proven to introduce a suspension point
//             that breaks Task.immediate determinism (Variant 1 of initial experiment hung).
//
// Hypothesis: Without withTaskCancellationHandler, Task.immediate runs synchronously
//             through withCheckedContinuation body, registering before suspension.
//             CheckedContinuation<Void, Never> avoids existentials (Embedded-compatible).
//             Cancellation trade-off: run()/advance() must unpark before task sees cancel.
//
// Toolchain: Apple Swift 6.2.3 (swiftlang-6.2.3.3.21 clang-1700.6.3.2)
// Platform: macOS 26.0 (arm64)
//
// Result: CONFIRMED — 14/14 pass, 0/1000 advance failures, 0/1000 cancel failures
// Date: 2026-02-25

import Synchronization

// MARK: - Minimal Clock.Test reproduction

final class TestClock: @unchecked Sendable {
    struct Instant: Comparable, Sendable {
        let offset: Duration
        static func < (lhs: Self, rhs: Self) -> Bool { lhs.offset < rhs.offset }
    }

    struct Entry: Sendable {
        let id: UInt64
        let deadline: Instant
        let continuation: CheckedContinuation<Void, Never>
    }

    struct State: Sendable {
        var now: Instant
        var nextID: UInt64 = 0
        var suspensions: [Entry] = []
    }

    let state: Mutex<State>

    init(now: Instant = .init(offset: .zero)) {
        state = Mutex(State(now: now))
    }

    var now: Instant { state.withLock { $0.now } }

    // MARK: - sleep: withCheckedContinuation<Void, Never> only (no withTaskCancellationHandler)

    nonisolated(nonsending)
    func sleep(until deadline: Instant) async throws {
        try Task.checkCancellation()

        let shouldSuspend = state.withLock { $0.now < deadline }
        guard shouldSuspend else { return }

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            state.withLock { st in
                let id = st.nextID
                st.nextID &+= 1
                st.suspensions.append(Entry(
                    id: id,
                    deadline: deadline,
                    continuation: continuation
                ))
            }
        }

        try Task.checkCancellation()
    }

    // MARK: - advance (synchronous)

    func advance(by duration: Duration) {
        let target = Instant(offset: now.offset + duration)
        advance(to: target)
    }

    func advance(to deadline: Instant) {
        let toResume: [CheckedContinuation<Void, Never>] = state.withLock { st in
            st.now = deadline
            st.suspensions.sort { $0.deadline < $1.deadline }
            var ready: [CheckedContinuation<Void, Never>] = []
            while let head = st.suspensions.first, head.deadline.offset <= deadline.offset {
                ready.append(head.continuation)
                st.suspensions.removeFirst()
            }
            return ready
        }
        for c in toResume { c.resume() }
    }

    // MARK: - run (synchronous)

    func run() {
        let toResume: [CheckedContinuation<Void, Never>] = state.withLock { st in
            st.suspensions.sort { $0.deadline < $1.deadline }
            if let last = st.suspensions.last { st.now = last.deadline }
            let all = st.suspensions.map(\.continuation)
            st.suspensions.removeAll()
            return all
        }
        for c in toResume { c.resume() }
    }
}

// MARK: - Test infrastructure

let passed = Mutex(0)
let failed = Mutex(0)

func check(_ name: String, _ condition: Bool) {
    if condition {
        passed.withLock { $0 += 1 }
        print("  PASS: \(name)")
    } else {
        failed.withLock { $0 += 1 }
        print("  FAIL: \(name)")
    }
}

// MARK: - Variant 1: Basic sleep + advance (determinism)
// Hypothesis: Task.immediate registers sleep before advance() runs
// Result: CONFIRMED

print("Variant 1: Basic sleep + advance")
do {
    let clock = TestClock()

    let task = Task.immediate {
        try await clock.sleep(until: .init(offset: .seconds(5)))
    }

    let count = clock.state.withLock { $0.suspensions.count }
    check("sleep registered before advance", count == 1)

    clock.advance(by: .seconds(5))
    try await task.value
    check("task completed", true)
    check("now advanced", clock.now.offset == .seconds(5))
}

// MARK: - Variant 2: Multiple sleepers
// Hypothesis: Multiple Task.immediate calls all register synchronously
// Result: CONFIRMED

print("\nVariant 2: Multiple sleepers")
do {
    let clock = TestClock()
    let order = Mutex([Int]())

    let t1 = Task.immediate {
        try await clock.sleep(until: .init(offset: .seconds(2)))
        order.withLock { $0.append(1) }
    }

    let t2 = Task.immediate {
        try await clock.sleep(until: .init(offset: .seconds(4)))
        order.withLock { $0.append(2) }
    }

    let count = clock.state.withLock { $0.suspensions.count }
    check("both registered before advance", count == 2)

    clock.advance(by: .seconds(5))
    try await t1.value
    try await t2.value
    let o = order.withLock { $0 }
    check("resumed in deadline order", o == [1, 2])
}

// MARK: - Variant 3: run() processes all
// Hypothesis: run() collects and resumes all synchronously
// Result: CONFIRMED

print("\nVariant 3: run() processes all")
do {
    let clock = TestClock()
    let completed = Mutex(false)

    let task = Task.immediate {
        try await clock.sleep(until: .init(offset: .seconds(10)))
        completed.withLock { $0 = true }
    }

    clock.run()
    try await task.value
    check("task completed via run()", completed.withLock { $0 })
    check("now at last deadline", clock.now.offset == .seconds(10))
}

// MARK: - Variant 4: Cancellation requires run() to unpark
// Hypothesis: cancel sets flag, run() resumes continuation, checkCancellation() throws after wake
// Result: CONFIRMED

print("\nVariant 4: Cancellation + run()")
do {
    let clock = TestClock()

    let task = Task.immediate {
        try await clock.sleep(until: .init(offset: .seconds(100)))
    }

    let countBefore = clock.state.withLock { $0.suspensions.count }
    check("registered before cancel", countBefore == 1)

    task.cancel()
    clock.run()  // unpark the continuation so the task can observe cancellation
    let result = await task.result

    let countAfter = clock.state.withLock { $0.suspensions.count }
    check("entry removed by run()", countAfter == 0)

    switch result {
    case .success:
        check("throws CancellationError", false)
    case .failure(let error):
        check("throws CancellationError", error is CancellationError)
    }
}

// MARK: - Variant 5: Cancellation AFTER advance (post-wake)
// Hypothesis: advance() resumes first, then checkCancellation() detects cancel
// Result: CONFIRMED

print("\nVariant 5: Cancellation after advance")
do {
    let clock = TestClock()
    let woke = Mutex(false)

    let task = Task.immediate {
        try await clock.sleep(until: .init(offset: .seconds(5)))
        woke.withLock { $0 = true }
    }

    task.cancel()
    clock.advance(by: .seconds(5))
    let result = await task.result

    // advance() resumed the continuation. The post-sleep code ran (woke = true),
    // then try Task.checkCancellation() threw.
    // Actually — checkCancellation is BEFORE woke.withLock, so woke stays false.
    // Let me just check the error.
    switch result {
    case .success:
        check("throws CancellationError", false)
    case .failure(let error):
        check("throws CancellationError", error is CancellationError)
    }
}

// MARK: - Variant 6: Pre-cancelled task (regular Task, not Task.immediate)
// Hypothesis: With regular Task, if cancelled before sleep() runs, checkCancellation() bails out
// Result: CONFIRMED

print("\nVariant 6: Pre-cancelled regular task")
do {
    let clock = TestClock()

    let task = Task {
        try? await Task.sleep(for: .milliseconds(50)) // let cancel propagate
        try await clock.sleep(until: .init(offset: .seconds(5)))
    }
    task.cancel()
    let result = await task.result

    switch result {
    case .success:
        check("throws CancellationError", false)
    case .failure(let error):
        check("throws CancellationError", error is CancellationError)
    }
}

// MARK: - Variant 7: Determinism under repetition (1000 iterations)
// Hypothesis: 0/1000 failures for basic sleep + advance pattern
// Result: CONFIRMED

print("\nVariant 7: 1000-iteration determinism")
do {
    var failures = 0
    for _ in 0..<1000 {
        let clock = TestClock()

        let task = Task.immediate {
            try await clock.sleep(until: .init(offset: .seconds(1)))
        }

        let registered = clock.state.withLock { $0.suspensions.count == 1 }
        if !registered { failures += 1; continue }

        clock.advance(by: .seconds(1))

        do {
            try await task.value
        } catch {
            failures += 1
        }
    }
    check("0/1000 failures", failures == 0)
    if failures > 0 { print("    \(failures)/1000 failed") }
}

// MARK: - Variant 8: Cancellation determinism (1000 iterations)
// Hypothesis: 0/1000 failures for cancel-before-advance pattern
// Result: CONFIRMED
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES

print("\nVariant 8: 1000-iteration cancellation determinism")
do {
    var failures = 0
    for _ in 0..<1000 {
        let clock = TestClock()

        let task = Task.immediate {
            try await clock.sleep(until: .init(offset: .seconds(100)))
        }

        task.cancel()
        clock.run()  // unpark so task can observe cancellation
        let result = await task.result

        switch result {
        case .success:
            failures += 1
        case .failure(let error):
            if !(error is CancellationError) { failures += 1 }
        }
    }
    check("0/1000 cancellation failures", failures == 0)
    if failures > 0 { print("    \(failures)/1000 failed") }
}

// MARK: - Results Summary
let p = passed.withLock { $0 }
let f = failed.withLock { $0 }
print("\n--- Results ---")
print("Passed: \(p)")
print("Failed: \(f)")
if f > 0 { print("REFUTED") } else { print("CONFIRMED") }
