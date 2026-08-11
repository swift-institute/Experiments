// MARK: - Foreign Recycle Channel (Item C prototype)
// Purpose: Prototype the receive-pool recycle loop from the design doc's Residual #2
//          (finalizer executor affinity) against the REAL package and the REAL
//          Async.Channel: a pool actor owns provided regions; Memory.Foreign values'
//          finalizers enqueue the region back through a channel Sender; the pool
//          re-provides. Prototypes the D-residual annotation shape (sending results
//          vending non-Sendable ~Copyable values) before proposing it upstream.
// Hypotheses:
//   V1: a finalizer capturing the pool ACTOR (Sendable) and the channel Sender
//       (Sendable) keeps the Foreign's region disconnected — vend/cross/drop passes
//       region checking with zero @unchecked and zero @Sendable.
//   V2: assertIsolated() inside the finalizer observes that deinit runs on the
//       DROP-SITE executor, not the pool's — so a recycle closure must be
//       isolation-agnostic (channel send), never a direct pool-state touch.
//   V3: exactly-once recycling holds under concurrent consumers (Census exactness +
//       full inventory restoration).
//   V4: (a) Memory.Foreign — non-Sendable, ~Copyable — flows through the real
//       channel within one isolation domain today; (b) an ADDITIVE
//       `receiveSending()` extension over the real Receiver does or does not
//       satisfy region checking (determines whether Item D's one-line fix must
//       land on the original declaration); (c) `sending`-result vending works on
//       an actor method (Pool.vend — the fix's semantic shape).
//   V5: per-buffer recycle overhead (envelope + channel) vs direct re-provide.
//
// Toolchain: Apple Swift 6.3.2 (swiftlang-6.3.2.1.108 clang-2100.1.1.101)
// Platform: arm64-apple-macosx26.0
//
// Result: CONFIRMED across all variants.
//   V1 CONFIRMED — vend -> drop -> finalizer(send) -> drain -> re-provide, inventory
//      restored; finalizer captures Sender + Census (+ pool actor in V2's variant),
//      all Sendable, so the sending result leaves the pool legally. Zero @unchecked,
//      zero @Sendable annotations anywhere in this prototype.
//   V2 CONFIRMED — assertIsolated() in the finalizer: deinit runs on the DROP-SITE
//      executor (pool-side drop asserted the pool; consumer-side drop asserted the
//      consumer). Design consequence: recycle closures must be isolation-agnostic —
//      the channel send IS the design, not a convenience.
//   V3 CONFIRMED — 8 consumers x 200 cycles over a 4-region pool: 1600 vends,
//      1600 finalizations (Census exact), inventory fully restored.
//   V4a CONFIRMED — non-Sendable ~Copyable Memory.Foreign flows through the REAL
//      channel today when received and dropped in one isolation domain (send is
//      already `consuming sending`, Async.Channel.Unbounded.Sender.swift:76).
//   V4b (-DPROBE_ADDITIVE_SENDING) CONFIRMED, and stronger than hypothesized:
//      the ADDITIVE extension `receiveSending() -> sending Element?` over the real
//      Receiver COMPILES (the nonisolated(nonsending) receive() result is provably
//      disconnected in the wrapper's scope) AND the call-site exercise runs —
//      element received in the main domain, sent onward into the consumer actor,
//      finalized there. Item D's one-line fix is retrofittable without touching
//      …Receiver.swift:77-78; annotating the original declaration remains the
//      cleaner canonical landing.
//   NEGATIVE (-DNEGATIVE_PROBE_DIRECT_POOL) — a finalizer touching actor-isolated
//      pool state is rejected at the sending boundary:
//      "error: task or actor-isolated value cannot be sent" (main.swift:116).
//   V5 (release, 20k cycles) — envelope+channel 7,766 ns/cycle vs direct re-provide
//      3,110 ns/cycle => ~4,656 ns per-buffer recycle overhead. (Debug: 17,260 vs
//      8,652.) The delta is dominated by the extra channel hop and its
//      @_optimize(none)-pinned send/receive (upstream workaround), not by the
//      envelope (closure retain) itself. Datum for the recycle-channel design note:
//      batch recycling (send(contentsOf:) exists) or ring-local recycling on the
//      hot path; per-buffer channel hops are a ~4.7 microsecond tax.
// Date: 2026-06-12

import Memory_Foreign_Primitives
import Memory_Foreign_Primitives_Test_Support
import Async_Primitives_Core
import Async_Channel_Primitives

// MARK: - The pool

/// The receive-pool shape: owns provided regions, vends Foreign envelopes, takes
/// recycled regions back. The finalizer's only job is the Sendable channel send,
/// so it is isolation-agnostic by construction — V2 demonstrates why it must be.
actor Pool {
    private var available: [Span.Raw.Mutable]
    private let intake: Async.Channel<Span.Raw.Mutable>.Unbounded.Sender
    private let census: Memory.Foreign.Census

    init(
        regions: [Span.Raw.Mutable],
        intake: Async.Channel<Span.Raw.Mutable>.Unbounded.Sender,
        census: Memory.Foreign.Census
    ) {
        self.available = regions
        self.intake = intake
        self.census = census
    }

    var inventory: Int { available.count }

    /// The drain task hands recycled regions back through here.
    func provide(_ region: Span.Raw.Mutable) {
        available.append(region)
    }

    /// V1 + V4c: vends the envelope as a `sending` result — the same annotation
    /// shape the channel Receiver needs (Item D's one-line fix). The finalizer
    /// captures only Sendable state (Sender + Census), so the value's region
    /// stays disconnected and the result legally leaves the pool's isolation.
    func vend() -> sending Memory.Foreign? {
        guard let region = available.popLast() else { return nil }
        let intake = self.intake
        let census = self.census
        return unsafe Memory.Foreign(adopting: region) { recycled in
            census.record()
            try? intake.send(recycled)
        }
    }

    /// V2: vend with a finalizer that asserts it runs on `expected`'s executor.
    /// `any Actor` is Sendable, so the capture keeps the region disconnected —
    /// this is the "finalizer captures the pool actor" shape from the dispatch.
    func vend(assertingDropOn expected: any Actor) -> sending Memory.Foreign? {
        guard let region = available.popLast() else { return nil }
        let intake = self.intake
        let census = self.census
        return unsafe Memory.Foreign(adopting: region) { recycled in
            expected.assertIsolated("the finalizer must run on the drop-site executor")
            census.record()
            try? intake.send(recycled)
        }
    }

    /// V2a drop site: the envelope dies inside the pool's isolation.
    func consumeHere(_ foreign: consuming sending Memory.Foreign) {
        _ = foreign.capacity
    }

    /// V5 baseline: raw descriptor checkout (no envelope, no channel).
    func checkout() -> Span.Raw.Mutable? {
        available.popLast()
    }

    /// Final teardown: empty the pool so the regions can be deallocated.
    func drainAll() -> [Span.Raw.Mutable] {
        let all = available
        available = []
        return all
    }

    #if NEGATIVE_PROBE_DIRECT_POOL
    /// EXPECTED COMPILE ERROR: a finalizer body cannot touch actor-isolated pool
    /// state directly — the channel send is required, not stylistic.
    func vendTouchingPoolState() -> sending Memory.Foreign? {
        guard let region = available.popLast() else { return nil }
        return unsafe Memory.Foreign(adopting: region) { recycled in
            self.available.append(recycled)
        }
    }
    #endif
}

/// The other isolation domain for V2b and V4.
actor Consumer {
    func consume(_ foreign: consuming sending Memory.Foreign) {
        _ = foreign.capacity
    }
}

// MARK: - V4b: additive sending over the REAL receiver (compile probe)

#if PROBE_ADDITIVE_SENDING
extension Async.Channel.Unbounded.Receiver where Element: ~Copyable {
    /// Can Item D's fix be retrofitted in an extension, without touching the
    /// original declaration? If this compiles, the fix is additive; if the region
    /// checker rejects re-exporting a plain result as `sending`, the annotation
    /// must land on `receive()` itself (…Receiver.swift:77-78).
    func receiveSending() async throws(Async.Channel<Element>.Error) -> sending Element? {
        try await receive()
    }
}
#endif

// MARK: - Setup (locals inside run(); top-level bindings are globals and cannot be consumed)

func run() async throws {
    let regionCount = 4
    let regionBytes = 4096

    let census = Memory.Foreign.Census()
    var channel = Async.Channel<Span.Raw.Mutable>.Unbounded()
    let intake = channel.sender
    let ends = (consume channel).take().ends()

    let regions: [Span.Raw.Mutable] = (0..<regionCount).map { _ in
        unsafe .init(UnsafeMutableRawBufferPointer.allocate(byteCount: regionBytes, alignment: 16))
    }
    let pool = Pool(regions: regions, intake: intake, census: census)

    let drain = Task { [ends = consume ends] in
        do {
            while let region = try await ends.receiver.receive() {
                await pool.provide(region)
            }
        } catch {
            preconditionFailure("drain loop cancelled unexpectedly")
        }
    }

    /// Yields until the pool holds `expected` regions again (recycling is async).
    func settle(to expected: Int) async {
        var spins = 0
        while await pool.inventory < expected {
            spins += 1
            precondition(spins < 100_000, "recycling failed to settle")
            await Task.yield()
        }
    }

    // MARK: V1: the recycle loop end-to-end

    do {
        let foreign = await pool.vend()
        precondition(foreign != nil, "fresh pool must vend")
        _ = consume foreign
    }
    await settle(to: regionCount)
    precondition(census.invocations == 1, "one drop, one finalizer")
    print("V1 vend -> drop -> finalizer(send) -> drain -> re-provide, inventory restored: CONFIRMED")

    // MARK: V2: deinit runs on the drop-site executor

    if let local = await pool.vend(assertingDropOn: pool) {
        await pool.consumeHere(local)
    }
    await settle(to: regionCount)

    let consumer = Consumer()
    if let crossed = await pool.vend(assertingDropOn: consumer) {
        await consumer.consume(crossed)
    }
    await settle(to: regionCount)
    precondition(census.invocations == 3)
    print("V2 assertIsolated in finalizer: deinit runs on the DROP-SITE executor (pool drop asserted pool; consumer drop asserted consumer): CONFIRMED")

    // MARK: V3: exactly-once under concurrent consumers

    let consumers = 8
    let cyclesPerConsumer = 200
    // A second Census stands in as the vend counter: a local Atomic is ~Copyable and
    // cannot be captured by eight concurrent group closures; the Sendable census can.
    let vendCensus = Memory.Foreign.Census()
    let censusBefore = census.invocations

    await withTaskGroup(of: Void.self) { group in
        for _ in 0..<consumers {
            group.addTask {
                var remaining = cyclesPerConsumer
                while remaining > 0 {
                    if let foreign = await pool.vend() {
                        _ = foreign.capacity
                        remaining -= 1
                        vendCensus.record()
                    } else {
                        await Task.yield()
                    }
                }
            }
        }
    }
    await settle(to: regionCount)
    let stormVends = vendCensus.invocations
    precondition(stormVends == consumers * cyclesPerConsumer)
    precondition(census.invocations - censusBefore == stormVends, "exactly-once under contention")
    print("V3 \(consumers) consumers x \(cyclesPerConsumer) cycles over \(regionCount) regions: \(stormVends) vends, \(census.invocations - censusBefore) finalizations, inventory restored: CONFIRMED")

    // MARK: V4a: Memory.Foreign through the REAL channel, one isolation domain

    do {
        var foreignChannel = Async.Channel<Memory.Foreign>.Unbounded()
        let foreignSender = foreignChannel.sender
        let foreignEnds = (consume foreignChannel).take().ends()

        let v4Census = Memory.Foreign.Census()
        let v4Foreign = Memory.Foreign.fixture(byteCount: 64, census: v4Census)
        try foreignSender.send(v4Foreign)
        let received = try await foreignEnds.receiver.receive()
        precondition(received != nil)
        _ = consume received
        precondition(v4Census.invocations == 1)
        foreignEnds.close()
        print("V4a non-Sendable ~Copyable Memory.Foreign through the real channel (send: consuming sending; receive + drop in one domain): CONFIRMED")
    }

    #if PROBE_ADDITIVE_SENDING
    // MARK: V4b call-site exercise: receive HERE, hand off to ANOTHER domain.
    // The extension compiling is necessary but not sufficient — this drives the
    // sending result across an isolation boundary at runtime.
    do {
        var crossChannel = Async.Channel<Memory.Foreign>.Unbounded()
        let crossSender = crossChannel.sender
        let crossEnds = (consume crossChannel).take().ends()

        let crossCensus = Memory.Foreign.Census()
        try crossSender.send(Memory.Foreign.fixture(byteCount: 64, census: crossCensus))
        let crossed = try await crossEnds.receiver.receiveSending()
        precondition(crossed != nil)
        if let crossed {
            await consumer.consume(crossed)
        }
        precondition(crossCensus.invocations == 1, "finalizer ran in the consumer's domain")
        crossEnds.close()
        print("V4b additive receiveSending(): element received here, sent onward into the consumer actor, finalized there: CONFIRMED")
    }
    #endif

    // MARK: V5: per-buffer recycle overhead vs direct re-provide (report in release)

    let benchCycles = 20_000

    let envelopeStart = ContinuousClock.now
    var envelopeCycles = 0
    while envelopeCycles < benchCycles {
        if let foreign = await pool.vend() {
            _ = consume foreign
            envelopeCycles += 1
        } else {
            await Task.yield()
        }
    }
    await settle(to: regionCount)
    let envelopeTime = ContinuousClock.now - envelopeStart

    let directStart = ContinuousClock.now
    var directCycles = 0
    while directCycles < benchCycles {
        if let region = await pool.checkout() {
            await pool.provide(region)
            directCycles += 1
        } else {
            await Task.yield()
        }
    }
    let directTime = ContinuousClock.now - directStart

    func nanoseconds(_ duration: Duration) -> Int {
        Int(duration.components.seconds) * 1_000_000_000 + Int(duration.components.attoseconds / 1_000_000_000)
    }
    let envelopeNs = nanoseconds(envelopeTime) / benchCycles
    let directNs = nanoseconds(directTime) / benchCycles
    print("V5 per-cycle over \(benchCycles) cycles: envelope+channel \(envelopeNs) ns, direct re-provide \(directNs) ns, overhead \(envelopeNs - directNs) ns")

    // MARK: Teardown

    intake.close()
    await drain.value
    let leftover = await pool.drainAll()
    precondition(leftover.count == regionCount)
    for region in leftover {
        unsafe region.base.nullable.deallocate()
    }
}

try await run()
print("done")
