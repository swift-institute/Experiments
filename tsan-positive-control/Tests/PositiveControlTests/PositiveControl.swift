// TSan carved-gate POSITIVE CONTROL — durable home (re-homed in Round P P0.4 from the
// W1 shared-soundness spike, GOAL-tower-arc-shared-soundness §W1.3).
//
// Seeds intentional data races through the exact mechanism shape `Shared` relies on
// (a final class box behind `@unchecked Sendable`, reached from a uniqueness-gated CoW
// struct). These tests are EXPECTED to produce ThreadSanitizer reports: they are the
// LIVE-SIGNAL proof that the carved TSan gate ([TEST-037] + the compiler-bug catalog
// §B8 carve `-sil-disable-pass=lifetime-dependence-diagnostics`) still SEES real races
// — i.e. the carve narrows the diagnostic, it does not blind the sanitizer. A quiet TSan
// run on the real suites is only interpretable when this control still fires.
//
// Run + expected output: see README.md. Expected: >0 `ThreadSanitizer: data race`.

import Testing

/// The box shape under test: unsynchronized stored state behind `@unchecked Sendable` —
/// the shape `Shared`'s `Box` keeps race-free by manual CoW reasoning. Here the
/// reasoning is deliberately violated.
final class RacedBox: @unchecked Sendable {
    var value: Int = 0
    init() {}
    func clone() -> RacedBox {
        let b = RacedBox()
        b.value = value
        return b
    }
}

/// CoW wrapper modeling `Shared`'s mechanism: a lawful uniqueness-gated lane plus the
/// assume-unique lane with the gate bypassed (the `-O` behavior of the debug assert).
struct RacedCoW: @unchecked Sendable {
    var box = RacedBox()

    /// Lawful lane (shape parity only; not exercised by the controls).
    mutating func bump() {
        if !isKnownUniquelyReferenced(&box) { box = box.clone() }
        box.value &+= 1
    }

    /// The unchecked lane with the debug assert compiled away: writes the box WITHOUT
    /// restoring uniqueness — the misuse class the carved gate must be able to see.
    mutating func bumpAssumingUnique() {
        box.value &+= 1
    }
}

@Suite struct PositiveControl {
    /// Control 1 — the canonical race: N tasks RMW the same box field unsynchronized.
    /// TSan MUST report a data race here, or the gate has no signal.
    @Test func boxRace() async {
        let box = RacedBox()
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<4 {
                group.addTask {
                    for _ in 0..<100_000 { box.value &+= 1 }
                }
            }
        }
        #expect(box.value > 0)
    }

    /// Control 2 — the `Shared`-misuse shape: sibling copies share one box; every task
    /// mutates through the assume-unique lane (gate present at the type, bypassed at the
    /// call). The racing accesses sit exactly where `Shared`'s would: the box's wrapped
    /// state, reached from a uniqueness-gated CoW struct under a TaskGroup.
    @Test func gateBypassRace() async {
        let proto = RacedCoW()
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<4 {
                group.addTask {
                    var mine = proto  // sibling copy: SAME box, refcount > 1
                    for _ in 0..<100_000 { mine.bumpAssumingUnique() }
                }
            }
        }
        #expect(proto.box.value > 0)
    }
}
