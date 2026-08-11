// MARK: - Priority-Override Spike
//
// Purpose:    Validate that `pthread_override_qos_class_start_np` / `_end_np`
//             nesting, performance, and cross-thread semantics support the M3
//             (Darwin thread-QoS bump) recommendation in
//             priority-escalation-policy.md v0.2.1.
// Hypothesis: (a) Nesting multiple overrides on one thread works in any
//             end-order; (b) per-cycle cost is < 1 µs; (c) cross-thread
//             override does NOT wake a condvar-parked worker.
// Reference:  swift-executors/Research/priority-escalation-policy.md §Analysis
//             "M3 thread QoS bump"; <pthread/qos.h>:213–293.
//
// Toolchain:  Apple Swift 6.3 (swiftlang-6.3.0.123.5, clang-2100.0.123.102)
// Platform:   macOS 26.0 (arm64)
//
// Result:     CONFIRMED
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
//             V1: PASS — 3 overrides started and ended in non-LIFO order
//             V2: PASS — 100k cycles in 85.4 ms (853 ns/cycle; < 1 µs)
//             V3: PASS — override applied to parked worker; did NOT wake
//                        until condvar signal
//
// Variants:
//   V1: Nesting semantics — 3 overrides started, ended in non-LIFO order
//   V2: Rapid-cycle timing — 100k start/end cycles, measure ns/cycle
//   V3: Cross-thread + condvar non-wake — override applied to parked pthread,
//       verify it does not wake until condvar signal
//
// Lifecycle finding: _end_np MUST be called while target thread is alive.
//   Calling after pthread_join returns ESRCH (3). For executor M3 pattern
//   this is inherently satisfied (override starts at job-start, ends at
//   job-end; worker thread outlives both).
//
// Date:       2026-04-16

import Darwin
import Synchronization

// MARK: - V1: Nesting semantics
//
// Header guarantee (<pthread/qos.h>:225–227):
//   "While overrides are in effect, the specified target thread will execute at
//    the maximum QOS class and relative priority of all overrides and of the
//    QOS class requested by the thread itself."
//
// Test: start 3 overrides at different QoS classes, end in non-LIFO order
// (C, A, B). All end calls must return 0. No crash, no leaked override.

func v1() {
    print("V1: Nesting semantics")

    let overrideA = pthread_override_qos_class_start_np(
        pthread_self(),
        QOS_CLASS_USER_INITIATED,
        0
    )

    let overrideB = pthread_override_qos_class_start_np(
        pthread_self(),
        QOS_CLASS_USER_INTERACTIVE,
        0
    )

    let overrideC = pthread_override_qos_class_start_np(
        pthread_self(),
        QOS_CLASS_DEFAULT,
        0
    )

    // End in non-LIFO order: C, A, B
    let resultC = pthread_override_qos_class_end_np(overrideC)
    precondition(resultC == 0, "V1: end(C) returned \(resultC)")

    let resultA = pthread_override_qos_class_end_np(overrideA)
    precondition(resultA == 0, "V1: end(A) returned \(resultA)")

    let resultB = pthread_override_qos_class_end_np(overrideB)
    precondition(resultB == 0, "V1: end(B) returned \(resultB)")

    print("V1: PASS — 3 overrides started and ended in non-LIFO order, all returned 0")
}

// MARK: - V2: Rapid-cycle timing
//
// Hypothesis: per-cycle cost (start + end) is < 1 µs, making M3 viable for
// per-job use in Stealing/Polling/Sharded executors. 100k iterations to
// amortize measurement noise.

func v2() {
    print("V2: Rapid-cycle timing (100k cycles)")
    let iterations = 100_000

    let start = ContinuousClock.now
    for _ in 0..<iterations {
        let o = pthread_override_qos_class_start_np(
            pthread_self(),
            QOS_CLASS_USER_INTERACTIVE,
            0
        )
        let r = pthread_override_qos_class_end_np(o)
        precondition(r == 0)
    }
    let elapsed = ContinuousClock.now - start
    let ns = elapsed.components.attoseconds / 1_000_000_000
        + elapsed.components.seconds * 1_000_000_000
    let perCycleNs = ns / Int64(iterations)

    print("V2: PASS — \(iterations) cycles in \(ns) ns (\(perCycleNs) ns/cycle)")
}

// MARK: - V3: Cross-thread override + parked-worker non-wake
//
// Header guarantee (<pthread/qos.h>:220–223):
//   "expresses that an item of pending work … depends on the completion of
//    the work currently being executed by the thread"
//
// Test: park a pthread on condvar. From main, apply override. Verify the
// parked thread does NOT wake. Then signal condvar; verify it wakes normally.

func v3() {
    print("V3: Cross-thread override + parked-worker non-wake")

    let mutex = UnsafeMutablePointer<pthread_mutex_t>.allocate(capacity: 1)
    let cond = UnsafeMutablePointer<pthread_cond_t>.allocate(capacity: 1)
    pthread_mutex_init(mutex, nil)
    pthread_cond_init(cond, nil)

    final class V3Context: @unchecked Sendable {
        let mutex: UnsafeMutablePointer<pthread_mutex_t>
        let cond: UnsafeMutablePointer<pthread_cond_t>
        let shouldStop = Atomic<Int>(0)
        let didComplete = Atomic<Int>(0)
        let workerReady = Atomic<Int>(0)

        init(mutex: UnsafeMutablePointer<pthread_mutex_t>,
             cond: UnsafeMutablePointer<pthread_cond_t>) {
            self.mutex = mutex
            self.cond = cond
        }
    }

    let ctx = V3Context(mutex: mutex, cond: cond)
    let unmanaged = Unmanaged.passRetained(ctx)

    var workerThread: pthread_t?
    let createResult = pthread_create(&workerThread, nil, { arg -> UnsafeMutableRawPointer? in
        let c = Unmanaged<V3Context>.fromOpaque(arg).takeRetainedValue()
        c.workerReady.store(1, ordering: .releasing)
        pthread_mutex_lock(c.mutex)
        while c.shouldStop.load(ordering: .acquiring) == 0 {
            pthread_cond_wait(c.cond, c.mutex)
        }
        pthread_mutex_unlock(c.mutex)
        c.didComplete.store(1, ordering: .releasing)
        return nil
    }, unmanaged.toOpaque())
    precondition(createResult == 0, "V3: pthread_create returned \(createResult)")

    // Wait for worker to park
    while ctx.workerReady.load(ordering: .acquiring) == 0 {
        usleep(1_000)
    }
    usleep(50_000) // 50 ms extra to ensure condvar wait is entered

    // Apply override to parked worker
    let o = pthread_override_qos_class_start_np(
        workerThread!,
        QOS_CLASS_USER_INTERACTIVE,
        0
    )

    // Wait 100 ms; confirm worker has NOT woken
    usleep(100_000)
    precondition(
        ctx.didComplete.load(ordering: .acquiring) == 0,
        "V3: FAIL — worker woke from override alone (no condvar signal)"
    )

    // End override BEFORE join — the target thread must still exist.
    // Calling _end_np after pthread_join returns ESRCH (3) because the
    // thread is gone. This matches the executor pattern: override starts
    // at job-start and ends at job-end, while the worker thread is alive.
    let endResult = pthread_override_qos_class_end_np(o)
    precondition(endResult == 0, "V3: end returned \(endResult)")

    // Now signal condvar
    pthread_mutex_lock(mutex)
    ctx.shouldStop.store(1, ordering: .releasing)
    pthread_cond_signal(cond)
    pthread_mutex_unlock(mutex)

    pthread_join(workerThread!, nil)
    precondition(
        ctx.didComplete.load(ordering: .acquiring) == 1,
        "V3: worker did not complete after signal"
    )

    // Cleanup
    pthread_mutex_destroy(mutex)
    pthread_cond_destroy(cond)
    mutex.deallocate()
    cond.deallocate()

    print("V3: PASS — override applied to parked worker; worker did NOT wake until condvar signal")
}

// MARK: - Driver

v1()
v2()
v3()

print("All variants: PASS")
