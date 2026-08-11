// MARK: - Two-Clock Scheduled-Executor Spike
//
// Purpose:    Validate that `Executor.Scheduled<Base>` can carry two
//             independent per-clock timer threads (ContinuousClock +
//             SuspendingClock) sharing a single shutdown flag without
//             deadlocking under shutdown race.
// Reference:  swift-executors/Research/scheduled-executor-policy.md
//             Q3 "Clock generality" (option B: two hardcoded clocks for v1).
//
// Hypotheses:
//   H1. Two timer threads, each parked on its own condvar waiting on its
//       own clock's next deadline, can be torn down by a single shared
//       shutdown flag + broadcast on both condvars.
//   H2. The two heaps drain independently; neither thread ever peeks
//       into the other's heap.
//   H3. Under shutdown race (both threads parked on "wait until future
//       deadline", shutdown flipped from main), both threads unblock
//       within a single-digit-millisecond bound.
//
// Variants:
//   V1: Single-clock baseline — one timer thread (ContinuousClock) fires
//       a scheduled job on time. Sanity check for the harness.
//   V2: Two-clock parallel drain — schedule jobs on both clocks; both
//       timer threads fire their own clock's jobs, neither fires the
//       other's. Ordering within each clock is FIFO-by-sequence.
//   V3: Shutdown race — both threads parked on future deadlines.
//       Shutdown flag + broadcast wakes both. Both threads exit within
//       100 ms; join returns.
//   V4: Many-pending shutdown — many pending jobs on both clocks at
//       shutdown time. Verify shutdown does not deadlock.
//
// Out of scope:
//   - Device-suspend semantics on SuspendingClock are untestable from
//     userspace (no way to suspend the device from a unit-test harness).
//     The SuspendingClock deadline is treated as an ordinary monotonic
//     deadline for the purposes of this spike; the real-world suspend
//     behavior is stdlib-tested, not ours.
//   - Generic-over-Clock model: a generic PerClockTimer<C> hits a Swift
//     6.3 compiler crash in the SendNonSendable pass when the generic
//     class is referenced from a `@convention(c)` thread entry closure.
//     The two non-generic classes below duplicate the run-loop structure;
//     the production implementation can keep it generic because pthread
//     entry closures can live outside the generic class in the real
//     swift-executors code.
//
// Toolchain:  Apple Swift 6.3 (swiftlang-6.3.0.123.5)
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
// Platform:   macOS 26.0 (arm64)
//
// Date:       2026-04-16

import Darwin
import Synchronization

// ============================================================================
// MARK: - Shared shutdown flag
// ============================================================================

/// Shared shutdown flag (class — Atomic is noncopyable, so we share by reference).
final class ShutdownFlag: @unchecked Sendable {
    let atomic = Atomic<Bool>(false)
    func set() { atomic.store(true, ordering: .releasing) }
    func isSet() -> Bool { atomic.load(ordering: .acquiring) }
}

// ============================================================================
// MARK: - Per-clock timer (non-generic duplication)
// ============================================================================

struct ContinuousEntry: Sendable {
    let id: Int
    let deadline: ContinuousClock.Instant
    let sequence: UInt64
}

struct SuspendingEntry: Sendable {
    let id: Int
    let deadline: SuspendingClock.Instant
    let sequence: UInt64
}

final class ContinuousTimer: @unchecked Sendable {
    let clock = ContinuousClock()
    let shutdownFlag: ShutdownFlag
    let mutex: UnsafeMutablePointer<pthread_mutex_t>
    let cond: UnsafeMutablePointer<pthread_cond_t>
    var heap: [ContinuousEntry]
    var nextSequence: UInt64 = 0
    var fired: [Int] = []
    var thread: pthread_t?

    init(shutdownFlag: ShutdownFlag) {
        self.shutdownFlag = shutdownFlag
        self.mutex = unsafe .allocate(capacity: 1)
        self.cond = unsafe .allocate(capacity: 1)
        self.heap = []
        unsafe pthread_mutex_init(mutex, nil)
        unsafe pthread_cond_init(cond, nil)
    }

    func schedule(id: Int, at deadline: ContinuousClock.Instant) {
        unsafe pthread_mutex_lock(mutex)
        let seq = nextSequence
        nextSequence &+= 1
        heap.append(ContinuousEntry(id: id, deadline: deadline, sequence: seq))
        unsafe pthread_cond_broadcast(cond)
        unsafe pthread_mutex_unlock(mutex)
    }

    func snapshotFired() -> [Int] {
        unsafe pthread_mutex_lock(mutex)
        let copy = fired
        unsafe pthread_mutex_unlock(mutex)
        return copy
    }

    func start() {
        let unmanaged = Unmanaged.passRetained(self)
        var threadHandle: pthread_t?
        let rc = unsafe pthread_create(
            &threadHandle, nil, continuousEntry, unmanaged.toOpaque()
        )
        precondition(rc == 0, "pthread_create rc=\(rc)")
        self.thread = threadHandle
    }

    func wake() {
        unsafe pthread_mutex_lock(mutex)
        unsafe pthread_cond_broadcast(cond)
        unsafe pthread_mutex_unlock(mutex)
    }

    func join() {
        if let t = thread {
            unsafe pthread_join(t, nil)
            thread = nil
        }
    }

    fileprivate func runLoop() {
        while !shutdownFlag.isSet() {
            unsafe pthread_mutex_lock(mutex)
            while !shutdownFlag.isSet() {
                let now = clock.now
                var ready: [ContinuousEntry] = []
                var remaining: [ContinuousEntry] = []
                for entry in heap {
                    if entry.deadline <= now {
                        ready.append(entry)
                    } else {
                        remaining.append(entry)
                    }
                }
                heap = remaining
                if !ready.isEmpty {
                    ready.sort { lhs, rhs in
                        if lhs.deadline == rhs.deadline {
                            return lhs.sequence < rhs.sequence
                        }
                        return lhs.deadline < rhs.deadline
                    }
                    for entry in ready { fired.append(entry.id) }
                    continue
                }
                var soonest: ContinuousClock.Instant? = nil
                for entry in heap {
                    if let current = soonest {
                        if entry.deadline < current { soonest = entry.deadline }
                    } else {
                        soonest = entry.deadline
                    }
                }
                guard let nextDeadline = soonest else {
                    unsafe pthread_cond_wait(cond, mutex)
                    continue
                }
                let nanos = nanosOf(now.duration(to: nextDeadline))
                if nanos <= 0 { continue }
                var ts = timespec()
                unsafe clock_gettime(CLOCK_REALTIME, &ts)
                ts.tv_sec += Int(nanos / 1_000_000_000)
                ts.tv_nsec += Int(nanos % 1_000_000_000)
                if ts.tv_nsec >= 1_000_000_000 {
                    ts.tv_sec += 1
                    ts.tv_nsec -= 1_000_000_000
                }
                _ = unsafe pthread_cond_timedwait(cond, mutex, &ts)
            }
            unsafe pthread_mutex_unlock(mutex)
        }
    }

    deinit {
        unsafe pthread_mutex_destroy(mutex)
        unsafe pthread_cond_destroy(cond)
        unsafe mutex.deallocate()
        unsafe cond.deallocate()
    }
}

final class SuspendingTimer: @unchecked Sendable {
    let clock = SuspendingClock()
    let shutdownFlag: ShutdownFlag
    let mutex: UnsafeMutablePointer<pthread_mutex_t>
    let cond: UnsafeMutablePointer<pthread_cond_t>
    var heap: [SuspendingEntry]
    var nextSequence: UInt64 = 0
    var fired: [Int] = []
    var thread: pthread_t?

    init(shutdownFlag: ShutdownFlag) {
        self.shutdownFlag = shutdownFlag
        self.mutex = unsafe .allocate(capacity: 1)
        self.cond = unsafe .allocate(capacity: 1)
        self.heap = []
        unsafe pthread_mutex_init(mutex, nil)
        unsafe pthread_cond_init(cond, nil)
    }

    func schedule(id: Int, at deadline: SuspendingClock.Instant) {
        unsafe pthread_mutex_lock(mutex)
        let seq = nextSequence
        nextSequence &+= 1
        heap.append(SuspendingEntry(id: id, deadline: deadline, sequence: seq))
        unsafe pthread_cond_broadcast(cond)
        unsafe pthread_mutex_unlock(mutex)
    }

    func snapshotFired() -> [Int] {
        unsafe pthread_mutex_lock(mutex)
        let copy = fired
        unsafe pthread_mutex_unlock(mutex)
        return copy
    }

    func start() {
        let unmanaged = Unmanaged.passRetained(self)
        var threadHandle: pthread_t?
        let rc = unsafe pthread_create(
            &threadHandle, nil, suspendingEntry, unmanaged.toOpaque()
        )
        precondition(rc == 0, "pthread_create rc=\(rc)")
        self.thread = threadHandle
    }

    func wake() {
        unsafe pthread_mutex_lock(mutex)
        unsafe pthread_cond_broadcast(cond)
        unsafe pthread_mutex_unlock(mutex)
    }

    func join() {
        if let t = thread {
            unsafe pthread_join(t, nil)
            thread = nil
        }
    }

    fileprivate func runLoop() {
        while !shutdownFlag.isSet() {
            unsafe pthread_mutex_lock(mutex)
            while !shutdownFlag.isSet() {
                let now = clock.now
                var ready: [SuspendingEntry] = []
                var remaining: [SuspendingEntry] = []
                for entry in heap {
                    if entry.deadline <= now {
                        ready.append(entry)
                    } else {
                        remaining.append(entry)
                    }
                }
                heap = remaining
                if !ready.isEmpty {
                    ready.sort { lhs, rhs in
                        if lhs.deadline == rhs.deadline {
                            return lhs.sequence < rhs.sequence
                        }
                        return lhs.deadline < rhs.deadline
                    }
                    for entry in ready { fired.append(entry.id) }
                    continue
                }
                var soonest: SuspendingClock.Instant? = nil
                for entry in heap {
                    if let current = soonest {
                        if entry.deadline < current { soonest = entry.deadline }
                    } else {
                        soonest = entry.deadline
                    }
                }
                guard let nextDeadline = soonest else {
                    unsafe pthread_cond_wait(cond, mutex)
                    continue
                }
                let nanos = nanosOf(now.duration(to: nextDeadline))
                if nanos <= 0 { continue }
                var ts = timespec()
                unsafe clock_gettime(CLOCK_REALTIME, &ts)
                ts.tv_sec += Int(nanos / 1_000_000_000)
                ts.tv_nsec += Int(nanos % 1_000_000_000)
                if ts.tv_nsec >= 1_000_000_000 {
                    ts.tv_sec += 1
                    ts.tv_nsec -= 1_000_000_000
                }
                _ = unsafe pthread_cond_timedwait(cond, mutex, &ts)
            }
            unsafe pthread_mutex_unlock(mutex)
        }
    }

    deinit {
        unsafe pthread_mutex_destroy(mutex)
        unsafe pthread_cond_destroy(cond)
        unsafe mutex.deallocate()
        unsafe cond.deallocate()
    }
}

// C-style entry points for pthread_create — kept outside the class
// bodies to avoid the SendNonSendable SIL pass crash seen in Swift 6.3
// when a generic class is referenced from a `@convention(c)` closure.

func continuousEntry(_ arg: UnsafeMutableRawPointer) -> UnsafeMutableRawPointer? {
    let timer = unsafe Unmanaged<ContinuousTimer>.fromOpaque(arg).takeRetainedValue()
    timer.runLoop()
    return nil
}

func suspendingEntry(_ arg: UnsafeMutableRawPointer) -> UnsafeMutableRawPointer? {
    let timer = unsafe Unmanaged<SuspendingTimer>.fromOpaque(arg).takeRetainedValue()
    timer.runLoop()
    return nil
}

func nanosOf(_ duration: Swift.Duration) -> Int64 {
    let c = duration.components
    return c.seconds * 1_000_000_000 + c.attoseconds / 1_000_000_000
}

// ============================================================================
// MARK: - Composed two-clock executor
// ============================================================================

final class TwoClockScheduled: @unchecked Sendable {
    let continuous: ContinuousTimer
    let suspending: SuspendingTimer
    let shutdownFlag: ShutdownFlag

    init() {
        self.shutdownFlag = ShutdownFlag()
        self.continuous = ContinuousTimer(shutdownFlag: shutdownFlag)
        self.suspending = SuspendingTimer(shutdownFlag: shutdownFlag)
        continuous.start()
        suspending.start()
    }

    func shutdown() {
        shutdownFlag.set()
        continuous.wake()
        suspending.wake()
        continuous.join()
        suspending.join()
    }
}

// ============================================================================
// MARK: - V1: Single-clock baseline
// ============================================================================

func v1() {
    print("V1: Single-clock baseline")
    let exec = TwoClockScheduled()
    let deadline = ContinuousClock.now.advanced(by: .milliseconds(50))
    exec.continuous.schedule(id: 1, at: deadline)

    let waitStart = ContinuousClock.now
    while exec.continuous.snapshotFired().isEmpty {
        if ContinuousClock.now - waitStart > .seconds(1) {
            preconditionFailure("V1: job did not fire within 1s")
        }
        usleep(5_000)
    }
    let elapsed = ContinuousClock.now - waitStart

    exec.shutdown()

    let fired = exec.continuous.snapshotFired()
    precondition(fired == [1], "V1: expected [1], got \(fired)")
    let elapsedMs = nanosOf(elapsed) / 1_000_000
    precondition(elapsedMs >= 45, "V1: fired too early (\(elapsedMs) ms)")
    precondition(elapsedMs < 500, "V1: fired too late (\(elapsedMs) ms)")
    print("V1: PASS — job fired after \(elapsedMs) ms, shutdown clean")
}

// ============================================================================
// MARK: - V2: Two-clock parallel drain
// ============================================================================

func v2() {
    print("V2: Two-clock parallel drain")
    let exec = TwoClockScheduled()
    let nowC = ContinuousClock.now
    let nowS = SuspendingClock.now

    exec.continuous.schedule(id: 10, at: nowC.advanced(by: .milliseconds(40)))
    exec.continuous.schedule(id: 11, at: nowC.advanced(by: .milliseconds(80)))
    exec.suspending.schedule(id: 20, at: nowS.advanced(by: .milliseconds(60)))
    exec.suspending.schedule(id: 21, at: nowS.advanced(by: .milliseconds(100)))

    let waitStart = ContinuousClock.now
    while true {
        let cFired = exec.continuous.snapshotFired()
        let sFired = exec.suspending.snapshotFired()
        if cFired.count == 2 && sFired.count == 2 { break }
        if ContinuousClock.now - waitStart > .seconds(1) {
            preconditionFailure(
                "V2: not all jobs fired within 1s — c=\(cFired) s=\(sFired)"
            )
        }
        usleep(5_000)
    }

    exec.shutdown()

    let cFired = exec.continuous.snapshotFired()
    let sFired = exec.suspending.snapshotFired()
    precondition(cFired == [10, 11], "V2: continuous wrong order: \(cFired)")
    precondition(sFired == [20, 21], "V2: suspending wrong order: \(sFired)")

    for id in cFired { precondition(id < 20, "V2: continuous fired id \(id)") }
    for id in sFired { precondition(id >= 20, "V2: suspending fired id \(id)") }

    print("V2: PASS — heaps drain independently; continuous=\(cFired) suspending=\(sFired)")
}

// ============================================================================
// MARK: - V3: Shutdown race (both threads parked)
// ============================================================================

func v3() {
    print("V3: Shutdown race with both threads parked on future deadlines")
    let exec = TwoClockScheduled()
    exec.continuous.schedule(id: 999, at: ContinuousClock.now.advanced(by: .seconds(60)))
    exec.suspending.schedule(id: 9999, at: SuspendingClock.now.advanced(by: .seconds(60)))

    // Let both threads park on timed_wait
    usleep(50_000)

    let start = ContinuousClock.now
    exec.shutdown()
    let elapsed = ContinuousClock.now - start

    let elapsedMs = nanosOf(elapsed) / 1_000_000
    precondition(elapsedMs < 100, "V3: shutdown took \(elapsedMs) ms (expected < 100 ms)")

    let cFired = exec.continuous.snapshotFired()
    let sFired = exec.suspending.snapshotFired()
    precondition(cFired.isEmpty, "V3: far-future job fired on continuous: \(cFired)")
    precondition(sFired.isEmpty, "V3: far-future job fired on suspending: \(sFired)")

    print("V3: PASS — shutdown completed in \(elapsedMs) ms without firing parked jobs")
}

// ============================================================================
// MARK: - V4: Many-pending shutdown
// ============================================================================

func v4() {
    print("V4: Shutdown with many pending entries on both clocks")
    let exec = TwoClockScheduled()
    let nowC = ContinuousClock.now
    let nowS = SuspendingClock.now

    for i in 0..<50 {
        let ms: Swift.Duration = .milliseconds(Int.random(in: 100...5000))
        exec.continuous.schedule(id: i, at: nowC.advanced(by: ms))
        exec.suspending.schedule(id: 1000 + i, at: nowS.advanced(by: ms))
    }

    usleep(50_000)

    let start = ContinuousClock.now
    exec.shutdown()
    let elapsed = ContinuousClock.now - start

    let elapsedMs = nanosOf(elapsed) / 1_000_000
    precondition(elapsedMs < 100, "V4: shutdown took \(elapsedMs) ms with 100 pending")

    print("V4: PASS — shutdown with 100 pending completed in \(elapsedMs) ms")
}

// ============================================================================
// MARK: - Driver
// ============================================================================

v1()
v2()
v3()
v4()
print("All variants: PASS")
