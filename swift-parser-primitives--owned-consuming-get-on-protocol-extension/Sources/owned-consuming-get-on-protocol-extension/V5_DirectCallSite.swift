//
// V5 — Direct call-site at function scope (no consuming-parameter wrapper)
//
// V1-V4 use consuming-parameter wrappers to side-step the "borrowed by a non-
// Escapable type" diagnostic. Production callers do NOT wrap in such helpers —
// they write `parser.error.map { ... }` directly at function scope.
// This variant verifies whether the wrappers are actually required, or whether
// a direct call-site compiles too.
//
// Hypothesis: direct call-site at function scope FAILS (matches prior research's
// Phase-2 diagnostic on generic-enum), and the wrapper is mandatory.
//
// Empirical result on Swift 6.4-dev nightly 2026-05-12:
//   - Direct call-site FAILS with "noncopyable 'c' cannot be consumed when
//     captured by an escaping closure or borrowed by a non-Escapable type"
//     (same diagnostic that blocked Phase 2 in prior generic-enum research).
//   - Explicit `consume c` keyword CRASHES the compiler with a SIL verifier
//     abort at MemoryLifetimeVerifier.cpp:263 ("store-borrow location cannot
//     be written") — a separate compiler bug, not an authoring fix.
//
// The functions below are commented out because they (1) fail to compile and
// (2) crash the compiler on the consume-keyword variant. The diagnostic
// transcripts are recorded in EXPERIMENT.md.

/*
@inlinable
public func runV5DirectV2A() -> Int {
    let c = V2_Container<V1_NC>(V1_NC(99))
    return c.marker
    // error: noncopyable 'c' cannot be consumed when captured by an escaping
    //        closure or borrowed by a non-Escapable type
}

@inlinable
public func runV5DirectV3() -> Int {
    let c = V3_Container<Int>(42)
    let t = c.transform
    return t.tokenize()
    // error: same diagnostic
}

@inlinable
public func runV5DirectV4() -> Int {
    let c = V3_Container<Int>(7)
    let mapped: V4_Map<V3_Container<Int>, V4_NewFailure> =
        c.error.map { _ in V4_NewFailure.mapped(99) }
    return mapped.emit()
    // error: same diagnostic
}

@inlinable
public func runV5ConsumeKeyword() -> Int {
    let c = V3_Container<Int>(42)
    let t = (consume c).transform
    return t.tokenize()
    // CRASH: SIL memory lifetime failure (MemoryLifetimeVerifier.cpp:263):
    //   "store-borrow location cannot be written"
    //   memory location:  %22 = store_borrow %20 to %21 : $*V3_Container<Int>
    //   at instruction:   %24 = apply %23<V3_Container<Int>>(%15, %22) :
    //     $@convention(method) <τ_0_0 where τ_0_0 : V3_Protocol, τ_0_0 : ~Copyable>
    //     (@in τ_0_0) -> @out V3_Transform<τ_0_0>
}
*/
