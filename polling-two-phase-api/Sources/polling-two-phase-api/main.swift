// MARK: - Two-Phase Polling API Experiment
// Purpose: Validate that splitting a Polling-like executor's API into
//          init(source:) + start(tick:) (a) eliminates the [weak self]
//          definite-init problem that currently forces a Handle weak-box
//          in swift-io, and (b) allows sending @escaping on the tick
//          parameter so the closure's captures do not need @Sendable.
//
// Toolchain: Swift 6.3 (Xcode 26 beta)
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
// Platform: macOS 26.0 (arm64)
//
// Production context (swift-foundations/swift-io):
//   IO.Events.Actor owns a Kernel.Thread.Executor.Polling. The tick
//   closure needs [weak self] to avoid a retain cycle, but Polling.init
//   requires the tick at construction time. self.polling is the only
//   stored property being initialised — so at the point of the closure
//   literal, self is not yet fully-init and [weak self] is rejected by
//   the DI checker. Current workaround: IO.Events.Actor.Handle (a class
//   with weak actor reference) captured by the tick closure in place of
//   self.
//
// Hypothesis tested:
//   Two-phase init on the reactor (init() stores primitives, start()
//   spawns the thread and installs the tick) allows the actor to:
//     1. self.polling = FakePolling(source:)  // all stored props init
//     2. polling.start { [weak self] ... }    // self now fully-init
//   and this compiles on Swift 6.3 without nonisolated(unsafe),
//   without a weak-box helper, and with sending @escaping on the tick.
//
// Results:
//   V1 Basic two-phase compile                       : (filled after run)
//   V2 [weak self] in tick via start()               : (filled after run)
//   V3 sending @escaping on start() param            : (filled after run)
//   V4 assumeIsolated from tick body                 : (filled after run)
//   V5 actor pinning via unownedExecutor round-trip  : (filled after run)
//   V6 no premature tick firing before start()       : (filled after run)
//
// Date: 2026-04-15

import Synchronization
import Dispatch

print("=== polling-two-phase-api experiment START ===")

// ============================================================================
// MARK: - FakePolling: a minimal SerialExecutor with two-phase init
// ============================================================================

enum Outcome: Sendable { case `continue`, halt }

/// Emulates `Kernel.Thread.Executor.Polling` with a split API:
///   init(source:)      -- store primitives, NO thread, NO tick
///   start(tick:)       -- install tick, spawn thread
///   shutdown()         -- stop thread, join
///
/// Uses a serial DispatchQueue to emulate the polling thread. The tick
/// runs on that queue, outside a Swift Task context, so `assumeIsolated`
/// relies on `isIsolatingCurrentContext()` to verify identity via the
/// queue's dispatch specific key.
@safe
final class FakePolling: SerialExecutor, @unsafe @unchecked Sendable {
    let source: Int

    // Mutable storage protected by discipline — start() is called once
    // before the queue's work begins.
    private nonisolated(unsafe) var tick: ((() -> Int) -> Outcome)?
    private let queue: DispatchQueue
    private let _hasStarted: Atomic<Bool> = .init(false)
    private let _shutdown: Atomic<Bool> = .init(false)
    private let _tickFireCount: Atomic<Int> = .init(0)

    // Queue-specific key for identity comparison. Each FakePolling has
    // a unique Int tag on its queue; checking getSpecific at dispatch
    // time tells us whether we're on that queue. Int is Sendable, so
    // the key type is Sendable too.
    private static let identityKey = DispatchSpecificKey<Int>()
    private let myIdentity: Int

    init(source: Int) {
        self.source = source
        // ObjectIdentifier(self) would be ideal but we don't yet have self.
        // Use source as an identity proxy — each test uses distinct source.
        self.myIdentity = source
        self.queue = DispatchQueue(label: "FakePolling-\(source)")
        queue.setSpecific(key: Self.identityKey, value: myIdentity)
    }

    func start(tick: sending @escaping (() -> Int) -> Outcome) {
        unsafe (self.tick = tick)
        _hasStarted.store(true, ordering: .releasing)
        queue.async { [self] in self.runLoop() }
    }

    private func runLoop() {
        var iter = 0
        while !_shutdown.load(ordering: .acquiring) {
            guard let tick = unsafe self.tick else { break }
            _tickFireCount.wrappingAdd(1, ordering: .relaxed)
            let outcome = tick { iter }
            iter &+= 1
            if case .halt = outcome { break }
            Thread.sleep(forTimeInterval: 0.05)
        }
    }

    func shutdown() {
        // Set the shutdown flag; the runLoop observes it and exits.
        // We intentionally do NOT queue.sync(flags:.barrier) here —
        // if shutdown() is called from a job running on this queue
        // (e.g., an actor method pinned to this executor), sync-on-same-queue
        // would deadlock. The tick loop will exit on its next iteration.
        _shutdown.store(true, ordering: .releasing)
    }

    var hasStarted: Bool { _hasStarted.load(ordering: .acquiring) }
    var tickFireCount: Int { _tickFireCount.load(ordering: .relaxed) }

    // MARK: SerialExecutor

    func enqueue(_ job: consuming ExecutorJob) {
        let unowned = UnownedJob(job)
        queue.async { [self] in
            unsafe unowned.runSynchronously(on: self.asUnownedSerialExecutor())
        }
    }

    func asUnownedSerialExecutor() -> UnownedSerialExecutor {
        unsafe UnownedSerialExecutor(ordinary: self)
    }

    func isIsolatingCurrentContext() -> Bool? {
        DispatchQueue.getSpecific(key: Self.identityKey) == myIdentity
    }

    func checkIsolated() {
        guard isIsolatingCurrentContext() == true else {
            preconditionFailure("FakePolling: expected current context to be this reactor's queue")
        }
    }
}

import Foundation   // for Thread.sleep

// ============================================================================
// MARK: - V1: Basic two-phase init compiles
// ============================================================================
// Hypothesis: FakePolling.init(source:) + FakePolling.start(tick:) compiles,
//             thread is spawned only on start().

do {
    let p = FakePolling(source: 42)
    precondition(!p.hasStarted, "V1: not started yet")
    precondition(p.tickFireCount == 0, "V1: no tick fires before start()")
    p.start { _ in .halt }
    try? await Task.sleep(nanoseconds: 100_000_000)
    p.shutdown()
    precondition(p.hasStarted, "V1: started flag set")
    precondition(p.tickFireCount >= 1, "V1: tick fired at least once after start()")
    print("V1 CONFIRMED: two-phase construction and start compile; thread runs only after start(). Fires: \(p.tickFireCount)")
}

// ============================================================================
// MARK: - V6: No premature tick firing before start()
// ============================================================================
// Hypothesis: Constructing a FakePolling but never calling start() results
//             in zero tick fires.

do {
    let p = FakePolling(source: 7)
    try? await Task.sleep(nanoseconds: 50_000_000)
    precondition(p.tickFireCount == 0, "V6: zero fires without start()")
    precondition(!p.hasStarted, "V6: hasStarted false")
    print("V6 CONFIRMED: no queue work, no tick fires, without start(). Fires: \(p.tickFireCount)")
}

// ============================================================================
// MARK: - V2+V3+V4+V5: Actor-owned polling with [weak self] + sending + assumeIsolated
// ============================================================================
// Hypothesis (V2): In an actor's init, `self.polling = FakePolling(...)` makes
//   self fully-initialised; a subsequent `polling.start { [weak self] ... }`
//   compiles — DI rule satisfied.
//
// Hypothesis (V3): start(tick:) parameter is `sending @escaping`, so the
//   closure captures do NOT need @Sendable. The closure's `[weak self]` is
//   transferred via region rather than requiring Sendable conformance.
//
// Hypothesis (V4): Inside the tick, `self.assumeIsolated { ... }` succeeds
//   because FakePolling's `isIsolatingCurrentContext()` returns true when
//   called on the reactor queue.
//
// Hypothesis (V5): The actor is pinned to FakePolling via unownedExecutor.

actor Reactor {
    nonisolated let polling: FakePolling

    var observedValues: [Int] = []

    nonisolated var unownedExecutor: UnownedSerialExecutor {
        unsafe polling.asUnownedSerialExecutor()
    }

    init(source: Int) {
        self.polling = FakePolling(source: source)
        // self is fully initialised here — only one stored property,
        // and it was just assigned. [weak self] is legal below.
        polling.start { [weak self] getValue in
            guard let self else { return .halt }
            let observed = getValue()
            return self.assumeIsolated { isolatedSelf in
                isolatedSelf.observedValues.append(observed)
                if isolatedSelf.observedValues.count >= 3 {
                    return .halt
                }
                return .continue
            }
        }
    }

    func snapshot() -> [Int] { observedValues }
    func stop() { polling.shutdown() }
}

let actorRunResult = await {
    let reactor = Reactor(source: 99)
    var snap: [Int] = []
    for _ in 0..<40 {
        snap = await reactor.snapshot()
        if snap.count >= 3 { break }
        try? await Task.sleep(nanoseconds: 50_000_000)
    }
    await reactor.stop()
    return snap
}()

precondition(actorRunResult.count >= 3, "V2+V3+V4: tick dispatched 3 observations via assumeIsolated; got \(actorRunResult.count)")
print("V2 CONFIRMED: [weak self] in start() compiles after self.polling assignment; observations=\(actorRunResult)")
print("V3 CONFIRMED: sending @escaping tick accepts closure; no @Sendable on closure type")
print("V4 CONFIRMED: assumeIsolated from tick body succeeded (runtime)")

// ============================================================================
// MARK: - V5: Actor pinning round-trip — actor method runs on polling queue
// ============================================================================

actor PinnedActor {
    nonisolated let polling: FakePolling

    private var threadSampled: Int = 0

    nonisolated var unownedExecutor: UnownedSerialExecutor {
        unsafe polling.asUnownedSerialExecutor()
    }

    init(source: Int) {
        self.polling = FakePolling(source: source)
        polling.start { [weak self] _ in
            guard let self else { return .halt }
            return self.assumeIsolated { isolated in
                isolated.threadSampled += 1
                return isolated.threadSampled >= 2 ? .halt : .continue
            }
        }
    }

    func sampled() -> Int { threadSampled }
    func stop() { polling.shutdown() }
}

let pinned = PinnedActor(source: 0)
var sampled = 0
for _ in 0..<40 {
    sampled = await pinned.sampled()
    if sampled >= 2 { break }
    try? await Task.sleep(nanoseconds: 50_000_000)
}
await pinned.stop()
precondition(sampled >= 2, "V5: actor state mutated from tick on pinned executor; got \(sampled)")
print("V5 CONFIRMED: actor pinned to polling; tick mutated actor state via assumeIsolated. Samples: \(sampled)")

print("")
print("==== All variants CONFIRMED on Swift 6.3 ====")
