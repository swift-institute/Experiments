// MARK: - Sending + Mutex + ~Copyable Region Transfer
// Purpose: Determine how to return non-Sendable ~Copyable action types from
//          Mutex.withLock closures when values are moved from locked state.
//
// Context: Async.Channel state machine types (Decision, Action, Step) contain
//          Element: ~Copyable (no longer & Sendable). After removing @unchecked
//          Sendable from these types, Mutex.withLock rejects returns because
//          the compiler sees results as "task-isolated" rather than disconnected.
//
// Toolchain: Apple Swift 6.3 (swiftlang-6.3.0.123.5)
// Platform: macOS 26.0 (arm64)
//
// Results Summary:
//   V1  — CONFIRMED: sync context, basic withLock return (no captures)
//   V2  — REFUTED:   sync context, inout capture merges regions
//   V3  — CONFIRMED: async context, basic withLock return (no captures)
//   V4  — REFUTED:   async context, inout capture same failure as V2
//   V5  — REFUTED:   withLockAndElement wrapper — same inout issue
//   V6  — REFUTED:   sending on state machine methods — errors inside methods
//   V7  — CONFIRMED: nonisolated(unsafe) on let binding (basic case only)
//   V8  — REFUTED:   unsafe expression — doesn't suppress region checks
//   V9  — REFUTED:   nonisolated(unsafe) var — still fails
//   V10 — REFUTED:   sync helper function — still fails
//   V11 — REFUTED:   consuming sending + nonisolated(unsafe) — still fails
//   V12 — REFUTED:   Storage bridge with nonisolated(unsafe) var — still fails
//   V13 — REFUTED:   separate decide+act — any withLock with non-Sendable capture fails
//   V14 — REFUTED:   custom withLock with nonisolated(unsafe) let inside — still fails
//   V15 — CONFIRMED: Sendable Slot intermediary + direct Mutex.withLock
//   V16 — REFUTED:   Slot + wrapper method — body closure indirection breaks it
//   V17 — REFUTED:   pointer bridge — still inout region merge
//   V18 — CONFIRMED: full send pattern (Slot + put-back) + direct Mutex.withLock
//   V19 — REFUTED:   Storage.withLock passthrough wrapper — compiler can't see through
//   V20 — REFUTED:   receive via wrapper — same wrapper issue
//   V21 — REFUTED:   storage.mutex.withLock — capturing storage merges regions
//   V22 — REFUTED:   @inline(__always) on wrapper — no effect on type checking
//   V23 — CONFIRMED: local Slot binding + storage.mutex.withLock (no storage capture)
//
// Key Findings:
//   1. Mutex.withLock has special compiler support for region disconnection.
//      Wrapper methods with identical signatures do NOT get this treatment.
//   2. Any inout capture of a non-Sendable variable in the withLock closure
//      merges the closure's region with the variable's region, making the
//      inout State parameter "task-isolated" and blocking sending returns.
//   3. The solution: use @unchecked Sendable intermediaries (Slot pattern)
//      to transfer non-Sendable values, and call Mutex.withLock directly
//      (not through wrapper methods).
//   4. The Slot must be captured as a standalone local, not accessed through
//      the object that owns the mutex.
//
// Production Impact:
//   - Storage.withLock / Storage.withLockAndElement wrappers cannot be used
//     when returning non-Sendable types. Callers must invoke the underlying
//     Mutex.withLock directly.
//   - Send fast path needs Ownership.Slot for element transfer (was inout Optional).
//   - Receive path needs direct mutex access (was wrapper).
//   - Ownership.Slot<Element> already exists on Storage (deliverySlot). A second
//     Slot may be needed for send-path element staging, or the existing Slot can
//     be reused if semantics allow.
//
// Date: 2026-03-30

import Synchronization

// ============================================================================
// Shared types used across variants
// ============================================================================

final class Payload {
    var data: Int
    init(_ data: Int) { self.data = data }
}

struct State: ~Copyable {
    var buffer: [Payload]
    var waiting: Bool

    init() {
        self.buffer = []
        self.waiting = false
    }

    mutating func trySend(_ element: inout Payload?) -> SendDecision {
        if waiting {
            waiting = false
            return .deliver(element.take()!)
        }
        buffer.append(element.take()!)
        return .buffered
    }

    mutating func tryReceive() -> ReceiveAction {
        if let element = buffer.first {
            buffer.removeFirst()
            return .element(element)
        }
        return .suspend
    }
}

enum SendDecision: ~Copyable {
    case deliver(Payload)
    case buffered
    case suspend
}

enum ReceiveAction: ~Copyable {
    case element(Payload)
    case suspend
}

final class Slot<T: ~Copyable>: @unchecked Sendable {
    var value: T?
    init(_ value: consuming T) { self.value = consume value }
    init() { self.value = nil }
    func take() -> T? { value.take() }
    func store(_ value: consuming T) { self.value = consume value }
}

// ============================================================================
// MARK: - V1: Sync context, basic withLock return
// Hypothesis: No captures → region analysis trivially passes.
// Result: CONFIRMED — Build Succeeded, Output: V1: sync basic — OK
// ============================================================================

func v1_sync_basic() {
    let m = Mutex(State())
    let action: ReceiveAction = m.withLock { state in
        state.tryReceive()
    }
    _ = consume action
    print("V1: sync basic — OK")
}

// ============================================================================
// MARK: - V3: Async context, basic withLock return
// Hypothesis: Same as V1 but in async context.
// Result: CONFIRMED — Build Succeeded, Output: V3: async basic — OK
// ============================================================================

func v3_async_basic() async {
    let m = Mutex(State())
    let action: ReceiveAction = m.withLock { state in
        state.tryReceive()
    }
    _ = consume action
    print("V3: async basic — OK")
}

// ============================================================================
// MARK: - V15: Sendable Slot intermediary + direct Mutex.withLock
// Hypothesis: Storing element in @unchecked Sendable Slot before entering
//             withLock avoids inout capture. Compiler sees only Sendable captures.
// Result: CONFIRMED — Build Succeeded, Output: V15: Sendable slot — OK
// ============================================================================

func v15_sendable_slot() async {
    let m = Mutex(State())
    let slot = Slot(Payload(42))
    let decision: SendDecision = m.withLock { state in
        var opt: Payload? = slot.take()
        return state.trySend(&opt)
    }
    _ = consume decision
    print("V15: Sendable slot — OK")
}

// ============================================================================
// MARK: - V18: Full send pattern with Slot + put-back
// Hypothesis: Complete send() pattern: create Slot, enter lock, trySend,
//             put element back in Slot if not consumed (suspend/reject).
// Result: CONFIRMED — Build Succeeded, Output: V18: buffered / V18: full send — OK
// ============================================================================

func v18_full_send_pattern(_ element: consuming sending Payload) async {
    let m = Mutex(State())
    let slot = Slot(consume element)
    let decision: SendDecision = m.withLock { state in
        var opt: Payload? = slot.take()
        let d = state.trySend(&opt)
        if let remaining = opt.take() {
            slot.store(remaining)
        }
        return d
    }
    switch consume decision {
    case .deliver(let p): print("V18: delivered \(p.data)")
    case .buffered:       print("V18: buffered")
    case .suspend:        print("V18: would suspend")
    }
    print("V18: full send pattern — OK")
}

// ============================================================================
// MARK: - V23: Local Slot binding + storage.mutex.withLock
// Hypothesis: Binding Slot to a local let, calling withLock on the Mutex
//             directly through storage (not through a wrapper method), and
//             NOT capturing the storage object itself in the closure.
// Result: CONFIRMED — Build Succeeded, Output: V23: local slot binding — OK
// ============================================================================

final class StorageV23: @unchecked Sendable {
    let mutex: Mutex<State>
    let deliverySlot: Slot<Payload>
    init() {
        mutex = Mutex(State())
        deliverySlot = Slot()
    }
}

func v23_local_slot_binding() async {
    let storage = StorageV23()
    let deliverySlot = storage.deliverySlot
    // Send
    let elementSlot = Slot(Payload(42))
    let decision: SendDecision = storage.mutex.withLock { state in
        var opt: Payload? = elementSlot.take()
        let d = state.trySend(&opt)
        if let remaining = opt.take() {
            elementSlot.store(remaining)
        }
        return d
    }
    _ = consume decision
    // Receive
    let action: ReceiveAction = storage.mutex.withLock { state in
        state.tryReceive()
    }
    switch consume action {
    case .element(let p):
        deliverySlot.store(p)
        print("V23: delivered to slot")
    case .suspend:
        print("V23: would suspend")
    }
    print("V23: local slot binding — OK")
}

// ============================================================================
// MARK: - V24: Wrapper with `inout sending` on body parameter
// Hypothesis: The stdlib Mutex.withLock uses `inout sending Value` (not just
//             `inout Value`). Adding `sending` to the wrapper's body parameter
//             gives the compiler the same region disconnection information.
// Result: (pending)
// ============================================================================

final class StorageV24: @unchecked Sendable {
    let mutex: Mutex<State>
    let deliverySlot: Slot<Payload>
    init() {
        mutex = Mutex(State())
        deliverySlot = Slot()
    }

    @inlinable
    func withLock<T: ~Copyable, E: Error>(
        _ body: (inout sending State) throws(E) -> sending T
    ) throws(E) -> sending T {
        try mutex.withLock(body)
    }

    @inlinable
    func withLockAndElement<T: ~Copyable, E: Error>(
        _ element: inout Payload?,
        _ body: (inout sending State, inout Payload?) throws(E) -> sending T
    ) throws(E) -> sending T {
        try mutex.withLock { (state: inout sending State) throws(E) -> T in
            try body(&state, &element)
        }
    }
}

func v24a_withLock_wrapper() async {
    let storage = StorageV24()
    // Prime buffer
    let slot = Slot(Payload(42))
    storage.withLock { state in
        var opt: Payload? = slot.take()
        _ = state.trySend(&opt)
    }
    // Receive via wrapper with inout sending
    let action: ReceiveAction = storage.withLock { state in
        state.tryReceive()
    }
    _ = consume action
    print("V24a: withLock wrapper (inout sending) — OK")
}

// V24b: REFUTED — withLockAndElement still fails because `inout Payload?`
// (non-Sendable) merges the closure's region. Even with `inout sending State`,
// the `inout Payload?` parameter contaminates the region.
// func v24b_withLockAndElement_wrapper() { ... }

// ============================================================================
// MARK: - Runner
// ============================================================================

v1_sync_basic()
await v3_async_basic()
await v15_sendable_slot()
await v18_full_send_pattern(Payload(99))
await v23_local_slot_binding()
await v24a_withLock_wrapper()
// await v24b_withLockAndElement_wrapper()  // known-failing: inout Payload? merges regions

print("\nAll confirmed variants passed.")
