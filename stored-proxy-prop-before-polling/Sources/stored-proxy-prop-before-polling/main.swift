// MARK: - Stored Handle-slot captured by name in tick closure
//
// Purpose: Instead of a LOCAL `let handle = Handle()` captured by the tick,
//          store the Handle as an actor stored property that is init'd
//          BEFORE `polling`. Then inside the polling-init closure, capture
//          the stored property explicitly: `[handle = self.handle]` or
//          just reference `self.handle`. The DI rule may or may not allow
//          access to one already-init'd stored property while another
//          (polling) is uninitialized.
//
//          If this works, it shows the Handle pattern is expressible
//          without a local-variable indirection. The workaround is not
//          eliminated — it's just stored.
//
// Hypothesis:
//   V1 — `[handle = self.handle]` fails. DI rejects any reference to
//        `self.*` during `self.polling = ...` expression because self is
//        still considered partially-initialized.
//   V2 — Using `let handle = Handle(); self.handle = handle; self.polling = ...`
//        (bind a local first, assign stored, then capture local) works —
//        but that's already the current pattern with handle as a local.
//        No win.
//
// Toolchain: Swift 6.3 (Xcode 26 beta)
// Platform: macOS 26.0 (arm64)
//
// Result: PARTIAL — V1 COMPILES (hypothesis wrong). DI permits
//   `[handle = self.handle]` because it is explicit-capture of an
//   already-initialized stored property, not a `self` capture. However,
//   this finding does NOT eliminate the Handle workaround — it only moves
//   `Handle` from a local to a stored property. The class, its
//   `@unchecked Sendable`, its `weak var actor`, and the tail-assignment
//   `handle.actor = self` all remain. Memory footprint increases by one
//   class-ref per actor instance.
//
//   V2 (current implementation) COMPILES and is the minimal pattern —
//   local `handle`, closure captures it, tail assignment. Storing
//   `handle` on the actor adds no functional value over a local binding.
//
//   The Handle workaround cannot be further reduced while preserving the
//   current actor-based design on Swift 6.3's DI rule.
//
// Date: 2026-04-15

enum Outcome: Sendable { case `continue`, halt }

@safe
final class FakePolling: @unsafe @unchecked Sendable {
    private nonisolated(unsafe) var tick: (() -> Outcome)?

    init(tick: sending @escaping () -> Outcome) {
        unsafe (self.tick = tick)
    }
}

final class Handle: @unchecked Sendable {
    weak var actorV1: ReactorV1?
    weak var actorV2: ReactorV2?
    init() {}
}

// ============================================================================
// MARK: - V1: Stored handle, explicit `[handle = self.handle]` capture
// ============================================================================

#if ENABLE_V1
actor ReactorV1 {
    nonisolated let handle: Handle
    nonisolated let polling: FakePolling
    var counter: Int = 0

    init() {
        self.handle = Handle()
        // EXPECTED: compile error — cannot reference self.handle in closure
        // while self.polling is uninitialized (DI rule).
        self.polling = FakePolling(tick: { [handle = self.handle] in
            guard let actor = handle.actorV1 else { return .halt }
            return actor.assumeIsolated { isolated in
                isolated.counter += 1
                return .continue
            }
        })
    }
}
#endif

// ============================================================================
// MARK: - V2: Local bind first, then assign to both stored props
// ============================================================================
// This IS the current Handle pattern; verify it compiles as a control.

actor ReactorV2 {
    nonisolated let handle: Handle
    nonisolated let polling: FakePolling
    var counter: Int = 0

    init() {
        let h = Handle()            // local
        self.handle = h             // store (redundant — see note below)
        self.polling = FakePolling(tick: { [h] in
            guard let actor = h.actorV2 else { return .halt }
            return actor.assumeIsolated { isolated in
                isolated.counter += 1
                return .continue
            }
        })
        h.actorV2 = self
    }
}

// Note: storing `handle` on the actor is redundant — the closure captures
// `h` directly and retains it via the tick closure's capture list. The
// stored property adds memory footprint for no benefit. The current
// implementation correctly uses ONLY a local.

print("V2 (current pattern, control): compiles: \(type(of: ReactorV2()))")
