//
//  probes.swift
//  Probes for W6 witness combinator call-site ergonomics.
//
//  Each probe is a candidate "clean call-site" shape that consumers would
//  write inside a `var body { ... }` of a conforming domain serializer.
//  We measure: does it compile? Does it leak the __WitnessX name? Does
//  it require outer-generic binding?
//

public import Witness_Core

// MARK: - BASELINE — the FAILING surface from the handoff

// Probe B1: Bare `Witness.Sequence.Two(p0, p1)` — handoff says FAILS.
// Uncomment to verify.
//
//  struct ProbeB1: Witness.`Protocol` {
//      typealias Output = ()
//      typealias Buffer = [UInt8]
//      typealias Failure = Never
//      var body: some Witness.`Protocol`<(), [UInt8], Never> {
//          // generic parameter 'Output' / 'Buffer' / 'Failure' could not be inferred
//          Witness.Sequence.Two(
//              Witness<(), [UInt8], Never> { _, _ in },
//              Witness<(), [UInt8], Never> { _, _ in }
//          )
//      }
//  }

// Probe B2: Bare `Witness.Literal<[UInt8]>("payload:")` — handoff says FAILS.
// VERIFIED FAILS: "generic parameter 'Output'/'Buffer'/'Failure' could not be
// inferred in cast to '__WitnessLiteral'".

// MARK: - CANDIDATE 4 — typealias on Witness.`Protocol` exposing Self.Literal

// Probe C4a — reference via `Self.Literal<...>` inside body.
struct ProbeC4a: Witness.`Protocol` {
    typealias Output = ()
    typealias Buffer = [UInt8]
    typealias Failure = Never
    var body: some Witness.`Protocol`<(), [UInt8], Never> {
        Self.Literal<[UInt8]>("payload:")
    }
}

// Probe C4b — reference via `Self.Sequence.Two<...>(...)` (constructor class)
struct ProbeC4b: Witness.`Protocol` {
    typealias Output = ()
    typealias Buffer = [UInt8]
    typealias Failure = Never
    var body: some Witness.`Protocol`<(), [UInt8], Never> {
        Self.Sequence.Two(
            Self.Literal<[UInt8]>("hello "),
            Self.Literal<[UInt8]>("world")
        )
    }
}

// Probe C4c — multi-element sequence (builder-produced via newline)
// This tests that the builder hoisted Sequence.Two is invoked correctly.
struct ProbeC4c: Witness.`Protocol` {
    typealias Output = ()
    typealias Buffer = [UInt8]
    typealias Failure = Never
    var body: some Witness.`Protocol`<(), [UInt8], Never> {
        Self.Literal<[UInt8]>("hello ")
        Self.Literal<[UInt8]>("world")
    }
}

// MARK: - Compare: does `Witness.Literal<[UInt8]>(...)` ALSO work after Cand 4?
//
// The original failing baseline (Probe B2) tested `Witness.Literal<[UInt8]>`
// — a hoisted typealias on `Witness` itself. Does adding the typealias on
// `Witness.Protocol` (Candidate 4) ALSO make `Witness.Literal<[UInt8]>` work?
// No — they are independent. `Witness.Literal` still requires binding the
// outer generics of `Witness`. Only the new `Self.Literal` path bypasses.

// MARK: - REAL-WORLD INTEGRATION — Map chain composed with Self.Literal
//
// Verifies Self.Literal composes with method-chain combinators (the Map
// path which already works in W6 production tests).

struct ProbeC4d: Witness.`Protocol` {
    typealias Output = ()
    typealias Buffer = [UInt8]
    typealias Failure = Never
    var body: some Witness.`Protocol`<(), [UInt8], Never> {
        // Literal followed by another Literal — multi-element body
        Self.Literal<[UInt8]>("prefix: ")
        Self.Literal<[UInt8]>("value")
    }
}

// MARK: - CANDIDATE 5 — non-generic peer enum `Witnesses` hosting typealiases

// Probe C5a — `Witnesses.Literal<[UInt8]>(...)` as type-reference
struct ProbeC5a: Witness.`Protocol` {
    typealias Output = ()
    typealias Buffer = [UInt8]
    typealias Failure = Never
    var body: some Witness.`Protocol`<(), [UInt8], Never> {
        Witnesses.Literal<[UInt8]>("payload:")
    }
}

// Probe C5b — `Witnesses.Sequence.Two(...)` as constructor
struct ProbeC5b: Witness.`Protocol` {
    typealias Output = ()
    typealias Buffer = [UInt8]
    typealias Failure = Never
    var body: some Witness.`Protocol`<(), [UInt8], Never> {
        Witnesses.Sequence.Two(
            Witnesses.Literal<[UInt8]>("hello "),
            Witnesses.Literal<[UInt8]>("world")
        )
    }
}

// Probe C5c — Multi-element body using newline (builder consumes)
struct ProbeC5c: Witness.`Protocol` {
    typealias Output = ()
    typealias Buffer = [UInt8]
    typealias Failure = Never
    var body: some Witness.`Protocol`<(), [UInt8], Never> {
        Witnesses.Literal<[UInt8]>("prefix: ")
        Witnesses.Literal<[UInt8]>("value")
    }
}

// MARK: - Sanity — does method-chain on Self.Literal still work?
// Tests that Self.Literal composes with existing combinator-method patterns.
//
// (Map/Filter not declared in this experiment, so we just verify that the
// concrete Self.Literal returns a Witness.Protocol value usable in the body
// — which the above multi-element probes already confirm.)

// MARK: - CANDIDATE 1 — static factory methods on Witness.`Protocol`

// Probe C1a — `Self.literal(...)` as factory call
struct ProbeC1a: Witness.`Protocol` {
    typealias Output = ()
    typealias Buffer = [UInt8]
    typealias Failure = Never
    var body: some Witness.`Protocol`<(), [UInt8], Never> {
        Self.literal("payload:")
    }
}

// MARK: - GENERIC CONFORMER — does each candidate work with a generic Buffer?

// Probe ProbeGen — generic over Buffer. The body must still resolve to a
// Witness.Protocol with matching Output/Buffer/Failure.
struct ProbeGenC4<B: RangeReplaceableCollection>: Witness.`Protocol`
where B.Element == UInt8 {
    typealias Output = ()
    typealias Buffer = B
    typealias Failure = Never
    var body: some Witness.`Protocol`<(), B, Never> {
        Self.Literal<B>("generic-buffer")
    }
}

struct ProbeGenC5<B: RangeReplaceableCollection>: Witness.`Protocol`
where B.Element == UInt8 {
    typealias Output = ()
    typealias Buffer = B
    typealias Failure = Never
    var body: some Witness.`Protocol`<(), B, Never> {
        Witnesses.Literal<B>("generic-buffer")
    }
}

// MARK: - Bare `Literal<[UInt8]>(...)` probe (no qualifier at all)
//
// Hypothesis: if the C4 typealias declares Literal on Witness.`Protocol`,
// and the body block context inside a Witness.`Protocol`-conforming type
// has Self bound, can Swift find Literal as an unqualified lookup?
//
// Result: probably NOT — Swift won't auto-implicit-Self for type-position
// lookups. But worth probing.

//  struct ProbeBare: Witness.`Protocol` {
//      typealias Output = ()
//      typealias Buffer = [UInt8]
//      typealias Failure = Never
//      var body: some Witness.`Protocol`<(), [UInt8], Never> {
//          Literal<[UInt8]>("test")  // does Literal resolve unqualified?
//      }
//  }


// MARK: - Probe W — current workaround (HOIST LEAK; principal rejects)

struct ProbeW: Witness.`Protocol` {
    typealias Output = ()
    typealias Buffer = [UInt8]
    typealias Failure = Never
    var body: some Witness.`Protocol`<(), [UInt8], Never> {
        __WitnessLiteral<[UInt8]>("payload:")  // leaks __Witness*
    }
}

// MARK: - Probe FB — full outer-binding (verbose; principal rejects as default)

struct ProbeFB: Witness.`Protocol` {
    typealias Output = ()
    typealias Buffer = [UInt8]
    typealias Failure = Never
    var body: some Witness.`Protocol`<(), [UInt8], Never> {
        Witness<Void, [UInt8], Never>.Literal<[UInt8]>("payload:")
    }
}
