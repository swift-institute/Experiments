// MARK: - Chase-Lev Deque Spike
//
// Purpose:    Verify the Swift stdlib `Synchronization` module suffices to
//             implement the Chase-Lev work-stealing deque (Lê, Pop, Cohen,
//             Zappa Nardelli 2013) for `Kernel.Thread.Executor.Stealing`.
// Hypothesis: `Synchronization.Atomic<Int>` exposes the orderings required
//             by the corrected algorithm: `.acquiring`, `.releasing`,
//             `.sequentiallyConsistent`. Full `atomic_thread_fence` is not
//             exposed but seq_cst on linked operations should provide
//             equivalent ordering for `take`/`steal` race resolution.
// Reference:  swift-executors/Research/work-stealing-scheduler-design.md
//             (Q1: deque ABI; next-step #1)
//
// Toolchain:  Apple Swift 6.3 (swiftlang-6.3.0.123.5, clang-2100.0.123.102)
// Platform:   macOS 26.0 (arm64)
//
// Result:     CONFIRMED
// Revalidated: Swift 6.3.1 (2026-04-30) — PASSES
//             V1: PASS — single-threaded LIFO/FIFO discipline holds
//             V2: PASS — pushed=100000, taken=12008, stolen=87992
//                       (UnsafeMutableBufferPointer storage)
//             V3: PASS — pushed=100000, taken=10006, stolen=89994
//                       (Memory.Inline<Int, 256> storage — ecosystem-typed)
//             V4: PASS — pushed=100000, taken=9999, stolen=90001
//                       (ManagedBuffer<Int, Int> storage — stdlib pattern)
// Date:       2026-04-16
//
// Variants:
//   V1: single-threaded smoke test, UnsafeMutableBufferPointer storage
//   V2: contended push/take/steal across N stealer Tasks, UMBP storage
//   V3: contended push/take/steal, Memory.Inline<Int, N> storage
//       (validates ecosystem-typed primitive compatibility per [DS-006])
//   V4: contended push/take/steal, ManagedBuffer<Int, Int> storage
//       (validates the stdlib _ContiguousArrayStorage pattern —
//       ContiguousArrayBuffer.swift:132 — for Chase-Lev's heap variant)
//
// Scope notes:
//   - Fixed-capacity deque (no dynamic resizing). Resizing is a separate
//     spike that does not need to gate Q1.
//   - Storage is `UnsafeMutableBufferPointer<Int>` directly. Production
//     `Executor.Job.Deque` will hold `UnownedJob`, but the atomic protocol
//     and ordering requirements are independent of element type.
//   - `@unchecked Sendable` on the deque is intentional: thread safety is
//     guaranteed by the Chase-Lev algorithm itself, not by the type system.

import Synchronization
import Memory_Inline_Primitives

// MARK: - Chase-Lev Deque

final class ChaseLevDeque: @unchecked Sendable {

    private let capacity: Int
    private let mask: Int
    private let storage: UnsafeMutableBufferPointer<Int>

    private let top: Atomic<Int>
    private let bottom: Atomic<Int>

    init(capacity: Int) {
        precondition(
            capacity > 0 && (capacity & (capacity - 1)) == 0,
            "capacity must be a power of two"
        )
        self.capacity = capacity
        self.mask = capacity - 1
        self.storage = .allocate(capacity: capacity)
        self.storage.initialize(repeating: -1)
        self.top = Atomic<Int>(0)
        self.bottom = Atomic<Int>(0)
    }

    deinit {
        storage.deinitialize()
        storage.deallocate()
    }

    // Owner-only. Returns false if full.
    func push(_ value: Int) -> Bool {
        let b = bottom.load(ordering: .relaxed)
        let t = top.load(ordering: .acquiring)
        if b - t >= capacity {
            return false
        }
        storage[b & mask] = value
        bottom.store(b + 1, ordering: .releasing)
        return true
    }

    // Owner-only. Returns nil if empty.
    func take() -> Int? {
        let oldB = bottom.load(ordering: .relaxed)
        let b = oldB - 1
        bottom.store(b, ordering: .sequentiallyConsistent)
        let t = top.load(ordering: .sequentiallyConsistent)

        if t > b {
            // Empty — restore bottom.
            bottom.store(oldB, ordering: .relaxed)
            return nil
        }

        let value = storage[b & mask]
        if t < b {
            return value
        }

        // Last element. Race with stealers via CAS on top.
        let (won, _) = top.compareExchange(
            expected: t,
            desired: t + 1,
            successOrdering: .sequentiallyConsistent,
            failureOrdering: .relaxed
        )
        bottom.store(oldB, ordering: .relaxed)
        return won ? value : nil
    }

    // Any thread. Returns nil if empty or contention loss.
    func steal() -> Int? {
        let t = top.load(ordering: .acquiring)
        let b = bottom.load(ordering: .acquiring)

        if t >= b {
            return nil
        }

        let value = storage[t & mask]
        let (won, _) = top.compareExchange(
            expected: t,
            desired: t + 1,
            successOrdering: .sequentiallyConsistent,
            failureOrdering: .relaxed
        )
        return won ? value : nil
    }
}

// MARK: - Counter Wrapper
// Atomic is ~Copyable; wrap in a Sendable class so closures can capture by
// reference cleanly without per-callsite borrowing dance.

final class Counters: @unchecked Sendable {
    let taken = Atomic<Int>(0)
    let stolen = Atomic<Int>(0)
    let pushDone = Atomic<Int>(0)
}

// MARK: - V1: single-threaded smoke test
// Hypothesis: With no contention, push/take/steal exhibit the documented
//             LIFO-owner / FIFO-stealer discipline.

func v1() {
    print("V1: single-threaded smoke test")
    let d = ChaseLevDeque(capacity: 8)

    for i in 0..<5 {
        precondition(d.push(i), "V1 push(\(i)) returned false")
    }

    // Owner pops LIFO: 4, 3
    precondition(d.take() == 4, "V1 expected take==4")
    precondition(d.take() == 3, "V1 expected take==3")

    // Stealer takes FIFO: 0
    precondition(d.steal() == 0, "V1 expected steal==0")

    // Owner takes remaining LIFO: 2, 1
    precondition(d.take() == 2, "V1 expected take==2")
    precondition(d.take() == 1, "V1 expected take==1")

    // Empty
    precondition(d.take() == nil, "V1 expected take==nil")
    precondition(d.steal() == nil, "V1 expected steal==nil")

    print("V1: PASS")
}

// MARK: - V2: contended push/take/steal
// Hypothesis: Across one owner Task and N stealer Tasks, every pushed value
//             is consumed exactly once (no losses, no duplicates). Count
//             reconciliation: pushed == taken + stolen.

func v2() async {
    print("V2: contended push/take/steal")
    let d = ChaseLevDeque(capacity: 4096)
    let counters = Counters()
    let totalPush = 100_000
    let stealerCount = 4

    await withTaskGroup(of: Void.self) { group in
        // Owner Task
        group.addTask {
            var pushed = 0
            var localTaken = 0
            while pushed < totalPush {
                if d.push(pushed) {
                    pushed += 1
                    // Periodically take from own end to exercise both ends.
                    if pushed % 10 == 0, d.take() != nil {
                        localTaken += 1
                    }
                } else {
                    // Full — yield so stealers can drain.
                    await Task.yield()
                }
            }
            // Drain remaining locally.
            while d.take() != nil {
                localTaken += 1
            }
            _ = counters.taken.wrappingAdd(localTaken, ordering: .releasing)
            counters.pushDone.store(1, ordering: .releasing)
        }

        // Stealer Tasks
        for _ in 0..<stealerCount {
            group.addTask {
                var localStolen = 0
                while counters.pushDone.load(ordering: .acquiring) == 0 {
                    if d.steal() != nil {
                        localStolen += 1
                    } else {
                        await Task.yield()
                    }
                }
                // Final drain after owner finished.
                while d.steal() != nil {
                    localStolen += 1
                }
                _ = counters.stolen.wrappingAdd(
                    localStolen,
                    ordering: .releasing
                )
            }
        }
    }

    let taken = counters.taken.load(ordering: .acquiring)
    let stolen = counters.stolen.load(ordering: .acquiring)
    let accounted = taken + stolen

    precondition(
        accounted == totalPush,
        "V2: accounted=\(accounted) != pushed=\(totalPush) (taken=\(taken), stolen=\(stolen))"
    )

    print("V2: PASS — pushed=\(totalPush), taken=\(taken), stolen=\(stolen)")
}

// MARK: - Chase-Lev Deque (Memory.Inline-backed)
// Generic on capacity so Memory.Inline<Int, capacity> can compute its
// inline storage layout at compile time. This is the shape `Static<N>`
// would take in production.

final class ChaseLevDequeInline<let capacity: Int>: @unchecked Sendable {

    private let mask: Int
    private let storage: Memory.Inline<Int, capacity>

    private let top: Atomic<Int>
    private let bottom: Atomic<Int>

    init() {
        precondition(
            capacity > 0 && (capacity & (capacity - 1)) == 0,
            "capacity must be a power of two"
        )
        self.mask = capacity - 1
        self.storage = Memory.Inline<Int, capacity>()
        for i in 0..<capacity {
            storage.pointer(at: i).initialize(to: -1)
        }
        self.top = Atomic<Int>(0)
        self.bottom = Atomic<Int>(0)
    }

    deinit {
        for i in 0..<capacity {
            storage.pointer(at: i).deinitialize(count: 1)
        }
    }

    func push(_ value: Int) -> Bool {
        let b = bottom.load(ordering: .relaxed)
        let t = top.load(ordering: .acquiring)
        if b - t >= capacity {
            return false
        }
        storage.pointer(at: b & mask).pointee = value
        bottom.store(b + 1, ordering: .releasing)
        return true
    }

    func take() -> Int? {
        let oldB = bottom.load(ordering: .relaxed)
        let b = oldB - 1
        bottom.store(b, ordering: .sequentiallyConsistent)
        let t = top.load(ordering: .sequentiallyConsistent)

        if t > b {
            bottom.store(oldB, ordering: .relaxed)
            return nil
        }

        let value = storage.pointer(at: b & mask).pointee
        if t < b {
            return value
        }

        let (won, _) = top.compareExchange(
            expected: t,
            desired: t + 1,
            successOrdering: .sequentiallyConsistent,
            failureOrdering: .relaxed
        )
        bottom.store(oldB, ordering: .relaxed)
        return won ? value : nil
    }

    func steal() -> Int? {
        let t = top.load(ordering: .acquiring)
        let b = bottom.load(ordering: .acquiring)

        if t >= b {
            return nil
        }

        let value = storage.pointer(at: t & mask).pointee
        let (won, _) = top.compareExchange(
            expected: t,
            desired: t + 1,
            successOrdering: .sequentiallyConsistent,
            failureOrdering: .relaxed
        )
        return won ? value : nil
    }
}

// MARK: - V3: Memory.Inline-backed contended push/take/steal
// Hypothesis: Memory.Inline<Int, capacity> from swift-memory-primitives
//             provides the same correctness guarantees as raw
//             UnsafeMutableBufferPointer for Chase-Lev's storage. Capacity
//             is reduced to 256 (a realistic Static<N> size) so push
//             back-pressure is more aggressive — pushed items spill more
//             often onto stealers.

func v3() async {
    print("V3: Memory.Inline-backed contended push/take/steal")
    let d = ChaseLevDequeInline<256>()
    let counters = Counters()
    let totalPush = 100_000
    let stealerCount = 4

    await withTaskGroup(of: Void.self) { group in
        group.addTask {
            var pushed = 0
            var localTaken = 0
            while pushed < totalPush {
                if d.push(pushed) {
                    pushed += 1
                    if pushed % 10 == 0, d.take() != nil {
                        localTaken += 1
                    }
                } else {
                    await Task.yield()
                }
            }
            while d.take() != nil {
                localTaken += 1
            }
            _ = counters.taken.wrappingAdd(localTaken, ordering: .releasing)
            counters.pushDone.store(1, ordering: .releasing)
        }

        for _ in 0..<stealerCount {
            group.addTask {
                var localStolen = 0
                while counters.pushDone.load(ordering: .acquiring) == 0 {
                    if d.steal() != nil {
                        localStolen += 1
                    } else {
                        await Task.yield()
                    }
                }
                while d.steal() != nil {
                    localStolen += 1
                }
                _ = counters.stolen.wrappingAdd(
                    localStolen,
                    ordering: .releasing
                )
            }
        }
    }

    let taken = counters.taken.load(ordering: .acquiring)
    let stolen = counters.stolen.load(ordering: .acquiring)
    let accounted = taken + stolen

    precondition(
        accounted == totalPush,
        "V3: accounted=\(accounted) != pushed=\(totalPush) (taken=\(taken), stolen=\(stolen))"
    )

    print("V3: PASS — pushed=\(totalPush), taken=\(taken), stolen=\(stolen)")
}

// MARK: - Chase-Lev Deque (ManagedBuffer-backed)
// Validates the stdlib _ContiguousArrayStorage pattern for the heap variant.
// Header carries capacity only (Int, Copyable — ManagedBuffer.create requires
// a value-returnable header). Atomics live in the wrapping class because
// Atomic is ~Copyable and cannot be returned from the create factory closure.
// Element access is through withUnsafeMutablePointerToElements per call,
// matching _ContiguousArrayStorage._elementPointer's compute-per-call shape
// (ContiguousArrayBuffer.swift:306).

final class ChaseLevDequeManaged: @unchecked Sendable {

    private let storage: ManagedBuffer<Int, Int>
    private let mask: Int
    private let top: Atomic<Int>
    private let bottom: Atomic<Int>

    init(capacity: Int) {
        precondition(
            capacity > 0 && (capacity & (capacity - 1)) == 0,
            "capacity must be a power of two"
        )
        self.mask = capacity - 1
        self.storage = ManagedBuffer<Int, Int>.create(
            minimumCapacity: capacity,
            makingHeaderWith: { _ in capacity }
        )
        self.top = Atomic<Int>(0)
        self.bottom = Atomic<Int>(0)
    }

    // Int is BitwiseCopyable — no per-slot deinit needed. ManagedBuffer's
    // own deallocation cleans up the tail-allocated Int storage.

    func push(_ value: Int) -> Bool {
        let b = bottom.load(ordering: .relaxed)
        let t = top.load(ordering: .acquiring)
        let cap = storage.header
        if b - t >= cap { return false }
        storage.withUnsafeMutablePointerToElements { ptr in
            ptr.advanced(by: b & mask).pointee = value
        }
        bottom.store(b + 1, ordering: .releasing)
        return true
    }

    func take() -> Int? {
        let oldB = bottom.load(ordering: .relaxed)
        let b = oldB - 1
        bottom.store(b, ordering: .sequentiallyConsistent)
        let t = top.load(ordering: .sequentiallyConsistent)

        if t > b {
            bottom.store(oldB, ordering: .relaxed)
            return nil
        }

        let value = storage.withUnsafeMutablePointerToElements { ptr in
            ptr.advanced(by: b & mask).pointee
        }
        if t < b {
            return value
        }

        let (won, _) = top.compareExchange(
            expected: t,
            desired: t + 1,
            successOrdering: .sequentiallyConsistent,
            failureOrdering: .relaxed
        )
        bottom.store(oldB, ordering: .relaxed)
        return won ? value : nil
    }

    func steal() -> Int? {
        let t = top.load(ordering: .acquiring)
        let b = bottom.load(ordering: .acquiring)

        if t >= b { return nil }

        let value = storage.withUnsafeMutablePointerToElements { ptr in
            ptr.advanced(by: t & mask).pointee
        }
        let (won, _) = top.compareExchange(
            expected: t,
            desired: t + 1,
            successOrdering: .sequentiallyConsistent,
            failureOrdering: .relaxed
        )
        return won ? value : nil
    }
}

// MARK: - V4: ManagedBuffer-backed contended push/take/steal
// Hypothesis: The stdlib ManagedBuffer<Header, Element> pattern — the
//             public-API equivalent of what _ContiguousArrayStorage uses
//             via Builtin.allocWithTailElems — provides correct Chase-Lev
//             semantics when paired with class-level Atomics.

func v4() async {
    print("V4: ManagedBuffer-backed contended push/take/steal")
    let d = ChaseLevDequeManaged(capacity: 4096)
    let counters = Counters()
    let totalPush = 100_000
    let stealerCount = 4

    await withTaskGroup(of: Void.self) { group in
        group.addTask {
            var pushed = 0
            var localTaken = 0
            while pushed < totalPush {
                if d.push(pushed) {
                    pushed += 1
                    if pushed % 10 == 0, d.take() != nil {
                        localTaken += 1
                    }
                } else {
                    await Task.yield()
                }
            }
            while d.take() != nil {
                localTaken += 1
            }
            _ = counters.taken.wrappingAdd(localTaken, ordering: .releasing)
            counters.pushDone.store(1, ordering: .releasing)
        }

        for _ in 0..<stealerCount {
            group.addTask {
                var localStolen = 0
                while counters.pushDone.load(ordering: .acquiring) == 0 {
                    if d.steal() != nil {
                        localStolen += 1
                    } else {
                        await Task.yield()
                    }
                }
                while d.steal() != nil {
                    localStolen += 1
                }
                _ = counters.stolen.wrappingAdd(
                    localStolen,
                    ordering: .releasing
                )
            }
        }
    }

    let taken = counters.taken.load(ordering: .acquiring)
    let stolen = counters.stolen.load(ordering: .acquiring)
    let accounted = taken + stolen

    precondition(
        accounted == totalPush,
        "V4: accounted=\(accounted) != pushed=\(totalPush) (taken=\(taken), stolen=\(stolen))"
    )

    print("V4: PASS — pushed=\(totalPush), taken=\(taken), stolen=\(stolen)")
}

// MARK: - Driver

v1()
await v2()
await v3()
await v4()

print("All variants: PASS")

// MARK: - Results Summary
// V1: CONFIRMED — single-threaded LIFO owner / FIFO stealer discipline
// V2: CONFIRMED — 100k items, 1 owner + 4 stealer Tasks, count reconciles
//                 (UMBP storage, 4096-slot)
// V3: CONFIRMED — same load on Memory.Inline<Int, 256>. Smaller capacity
//                 = more push back-pressure, exercising spill more.
// V4: CONFIRMED — same load on ManagedBuffer<Int, Int>, the stdlib pattern
//                 underlying _ContiguousArrayStorage. Atomics in the
//                 wrapping class (since ManagedBuffer.create requires a
//                 Copyable header).
//
// Conclusions:
//   1. Synchronization.Atomic<Int> with .acquiring/.releasing/
//      .sequentiallyConsistent suffices for the corrected Chase-Lev
//      algorithm on Swift 6.3 / macOS arm64. Promotes
//      work-stealing-scheduler-design.md Q1 next-step #1 from open to
//      validated for that target. Linux validation outstanding.
//   2. The atomic protocol is independent of storage: UMBP, Memory.Inline,
//      and ManagedBuffer all give identical correctness. Storage choice
//      is a layering question, not a correctness question.
//   3. Production storage recommendations:
//        - Static<N> variant: Memory.Inline<UnownedJob, N>
//        - Heap variant:      ManagedBuffer<Header, UnownedJob>
//          (matches stdlib's _ContiguousArrayStorage at
//          ContiguousArrayBuffer.swift:132-308; atomics in the wrapping
//          class since ManagedBuffer.create requires a Copyable header)
//   4. No new Storage primitive needed. The Storage taxonomy is curated
//      sequential lifecycle disciplines, not an orthogonal grid; Chase-Lev
//      is a concurrent collection primitive backed directly by
//      ManagedBuffer<H, E> — matching stdlib's _ContiguousArrayStorage
//      precedent. See
//      swift-primitives/swift-storage-primitives/Research/storage-primitives-modularization-review.md
//      (DECISION) for the closed analysis. ManagedBuffer is vestigial in
//      the ecosystem; replacement is a separate ecosystem-wide effort.
