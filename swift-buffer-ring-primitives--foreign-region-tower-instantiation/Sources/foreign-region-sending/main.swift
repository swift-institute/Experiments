// MARK: - Foreign-Region Sending (V5)
// Purpose: Verify the v1.1.0 concurrency posture of Memory.Foreign — NO Sendable
//          conformance, NO @Sendable finalizer requirement; isolation crossing is
//          region-based sending per [MEM-SEND-010]/[MEM-SEND-012]/[MEM-SEND-013].
//          Written in the R2 surface (Span.Raw.Mutable + plain closure), under the
//          ecosystem settings loop (.strictMemorySafety() + feature set).
// Hypothesis: (a) a non-Sendable ~Copyable Foreign whose finalizer captures only
//          Sendable state forms a disconnected region and crosses into another
//          isolation domain as a `sending` argument, where its drop runs the
//          finalizer exactly once; (b) a Foreign whose finalizer captures
//          actor-reachable non-Sendable state is rejected AT THE SEND SITE by the
//          region-isolation checker — per-send checking, no type-level promise.
//
// Toolchain: Apple Swift 6.3.2 (swiftlang-6.3.2.1.108 clang-2100.1.1.101)
// Platform: arm64-apple-macosx26.0
//
// Result: CONFIRMED (both directions)
//   V5a (positive): non-Sendable Foreign (finalizer capturing only Sendable state)
//        crossed into actor isolation as `consuming sending`; finalizer ran exactly
//        once in the sink's isolation. Output: "finalizer exactly-once = 1: CONFIRMED".
//        take() escapes custody without invoking; guarded deinit does not double-run
//        (witness 1 -> 2 only on manual invocation).
//   V5b (-DNEGATIVE_PROBE_SENDING): rejected AT THE SEND SITE —
//        "error: sending 'foreign' risks causing data races [#SendingRisksDataRace]"
//        "note: main actor-isolated 'foreign' is passed as a 'sending' parameter;
//         Uses in callee may race with later main actor-isolated uses"
//        (the finalizer's capture of MainActor-reachable non-Sendable state entangles
//        the value's region; per-send checking, no type-level promise needed).
//   DISCOVERY (surface-shaping): `discard self` requires trivially-destroyed stored
//        properties (Swift 6.3.2) — "can only 'discard' type 'Foreign' if it contains
//        trivially-destroyed stored properties at this time" — so a closure-bearing
//        ~Copyable cannot use the Memory.Contiguous-style discard-based take(); the
//        working shape is the Completion.Entry pattern (Optional field + guarded deinit).
//   ALSO: `sending` alone does not specify ownership for a ~Copyable parameter
//        ("parameter of noncopyable type 'Foreign' must specify ownership");
//        the spelling is `consuming sending`.
// Date: 2026-06-12
//
// Hazard notes ([MEM-SEND-009] et al.): no `inout sending` parameters anywhere
// (merge hazard); no withLock { $0 } capture-return shapes; the exactly-once
// witness is an Atomic global (referenced, not captured) because a plain class
// var cannot cross isolation and a captured ~Copyable Mutex would be consumed
// into the closure.

import Span_Primitives
import Memory_Primitives
import Synchronization

// MARK: - The R2 surface (doc v1.1.0 sketch shape)

/// The owning envelope around the ecosystem's existing non-owning descriptor:
/// `Span.Raw.Mutable` + finalizer + `~Copyable` uniqueness. NOT Sendable — the
/// closure field opens the region to captures the type cannot see; transferability
/// is checked per send by region isolation (terminal direction at birth,
/// [MEM-SEND-013]).
struct Foreign: ~Copyable {
    let region: Span.Raw.Mutable
    /// Optional SOLELY so `take()` can suppress the deinit's invocation:
    /// `discard self` requires trivially-destroyed stored properties (Swift 6.3.2
    /// diagnostic, V5 discovery), so a closure-bearing ~Copyable cannot use the
    /// discard-based escape hatch — the working shape is the Completion.Entry
    /// pattern (Optional field + guarded deinit). nil is reachable only via take().
    var _finalizer: ((Span.Raw.Mutable) -> Void)?

    init(adopting region: Span.Raw.Mutable, finalizer: @escaping (Span.Raw.Mutable) -> Void) {
        self.region = region
        self._finalizer = finalizer
    }

    consuming func take() -> (region: Span.Raw.Mutable, finalizer: (Span.Raw.Mutable) -> Void) {
        let result = (region, _finalizer!)
        _finalizer = nil
        return result
    }

    deinit {
        if let finalizer = _finalizer { finalizer(region) }
    }
}

extension Foreign: Memory.Region {
    var base: Memory.Address {
        // SAFETY: nonNull guarantees a non-null start even for empty regions.
        unsafe Memory.Address(region.base.nonNull.baseAddress!)
    }
    var capacity: Memory.Address.Count {
        Memory.Address.Count(UInt(unsafe region.base.nonNull.count))
    }
}

// MARK: - The other isolation domain

actor Sink {
    /// The Foreign arrives as a `sending` argument and is dropped at the end of
    /// this isolated method — the finalizer runs HERE, not where the value was made.
    func consume(_ foreign: consuming sending Foreign) {
        _ = foreign.capacity
    }
}

// MARK: - Variant 5a: disconnected-region Foreign crosses as sending (positive)

let v5aFinalized = Atomic<Int>(0)

func variant5a() async {
    let raw = unsafe UnsafeMutableRawBufferPointer.allocate(byteCount: 16, alignment: 16)
    let region: Span.Raw.Mutable = unsafe .init(raw)
    let poolTag = 7 // Sendable capture — the region stays disconnected
    let foreign = Foreign(adopting: region) { r in
        precondition(poolTag == 7)
        unsafe r.base.nullable.deallocate()
        v5aFinalized.wrappingAdd(1, ordering: .relaxed)
    }
    let sink = Sink()
    await sink.consume(foreign)
    let n = v5aFinalized.load(ordering: .sequentiallyConsistent)
    precondition(n == 1, "finalizer must run exactly once, in the sink's isolation")
    print("V5a non-Sendable Foreign sent across isolation, finalizer exactly-once = \(n): CONFIRMED")

    // take(): custody escapes WITHOUT invoking; the guarded deinit must not double-run.
    let raw2 = unsafe UnsafeMutableRawBufferPointer.allocate(byteCount: 16, alignment: 16)
    let second = Foreign(adopting: unsafe .init(raw2)) { r in
        unsafe r.base.nullable.deallocate()
        v5aFinalized.wrappingAdd(1, ordering: .relaxed)
    }
    let (takenRegion, takenFinalizer) = second.take()
    precondition(v5aFinalized.load(ordering: .sequentiallyConsistent) == 1, "take() must not invoke")
    takenFinalizer(takenRegion)
    precondition(v5aFinalized.load(ordering: .sequentiallyConsistent) == 2, "manual invocation after take()")
    print("V5a take() escapes custody without invoking; guarded deinit does not double-run: CONFIRMED")
}

await variant5a()

// MARK: - Variant 5b: actor-entangled Foreign is rejected at the send site
// (build with -Xswiftc -DNEGATIVE_PROBE_SENDING)

#if NEGATIVE_PROBE_SENDING
/// Deliberately non-Sendable.
final class Ledger {
    var entries: [Int] = []
}

/// MainActor-reachable state: appending `ledger` here merges it into the
/// MainActor's region BEFORE the finalizer captures it. (A static, not a
/// top-level var — top-level code variables cannot carry a global actor.)
@MainActor
enum V5B {
    static var retained: [Ledger] = []
}

@MainActor
func variant5b() async {
    let ledger = Ledger()
    V5B.retained.append(ledger)
    let raw = unsafe UnsafeMutableRawBufferPointer.allocate(byteCount: 16, alignment: 16)
    let foreign = Foreign(adopting: unsafe .init(raw)) { r in
        ledger.entries.append(unsafe r.base.nonNull.count)
        unsafe r.base.nullable.deallocate()
    }
    let sink = Sink()
    // EXPECTED: region-isolation diagnostic at this send site — `foreign`'s region
    // includes MainActor-reachable non-Sendable state via the closure capture.
    await sink.consume(foreign)
}
#endif

print("done")
