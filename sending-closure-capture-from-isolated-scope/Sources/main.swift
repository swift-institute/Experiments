//
// MARK: - Header
// Purpose: Verify whether Swift 6.3 rejects a closure literal passed to a
//   `sending @escaping` init parameter when the closure captures values
//   that were themselves imported via `sending` parameters (and/or
//   `consuming self`). This is the pattern used by the io-algebra
//   experiment's combinators.
//
// Hypothesis (from io-algebra iteration): Swift 6.3's region checker
//   DOES reject this pattern, producing `#SendingClosureRisksDataRace`
//   errors, even when every input is semantically in a disconnected
//   region. The checker cannot prove the closure's captures are
//   transferable despite their inputs being `sending`. This is a
//   compiler conservatism, not a semantic violation.
//
// Alternative hypotheses to discriminate between:
//   A) Region checker is correctly rejecting — we have a subtle semantic error
//   B) Region checker is conservative — the pattern IS safe but unprovable
//   C) The pattern works with a specific incantation we have not tried
//
// Toolchain: Swift 6.3 release
// Revalidated: Swift 6.3.1 (2026-04-17) — PASSES
// Platform: macOS 26 (arm64)
// Result: REFUTED — the "fundamental region-checker limitation" framing
//   was wrong. Variants V1/V2/V4/V5 fail; V3 compiles. The discriminator
//   is `@Sendable` on the stored function-typed property (and on any
//   function-typed parameters captured into the resulting `sending`
//   closure).
//
//   Specific diagnostic (V1, V2, V4, V5):
//     error: passing closure as a 'sending' parameter risks causing
//            data races ... [#SendingClosureRisksDataRace]
//     note: closure captures non-Sendable 'run'
//     note: closure captures non-Sendable 'transform'
//
//   V3 (with @Sendable on stored run + @Sendable on transform) compiles.
//
//   Conclusion: `@Sendable` on a function type is a CONCURRENCY ATTRIBUTE
//   on the function, distinct from `Value: Sendable` (a constraint on a
//   value type). The project axiom "minimize Sendable constraints" is
//   about value-type constraints. Function-type `@Sendable` is the
//   semantically-correct annotation when the closure crosses isolation
//   boundaries — it says "this closure is safe to call from any
//   isolation", which is precisely what `sending IO` requires.
//
//   V1/V2/V4/V5 were all asking the same question (can we avoid
//   `@Sendable` on the function type via sending/capture list/@concurrent
//   variations?) and got the same answer (no — function-type Sendability
//   is independent of value-region tracking).
//
// Date: 2026-04-17
//

// ============================================================================
// MARK: - Minimal shape — matches io-algebra's IO struct shape
// ============================================================================

/// Stand-in for the io-algebra `IO` struct. A stored `@concurrent` async
/// closure returning `sending Value`.
struct Box<Value> {
    let run: @concurrent () async -> sending Value

    init(_ run: sending @escaping @concurrent () async -> sending Value) {
        self.run = run
    }
}

// ============================================================================
// MARK: - V1: The failing pattern (reproduces io-algebra's combinator error)
// ============================================================================
// Hypothesis: the combinator below — consuming self, taking a sending
//   closure parameter, returning a `sending Box<New>` via init — fails
//   the region check with `#SendingClosureRisksDataRace` because the
//   captured `run` and `transform` are seen as task-isolated by the
//   region checker even though both are sourced from `sending`.
//
// Expected: REFUTED (build fails).

extension Box {
    consuming func v1_transform<New>(
        _ transform: sending @escaping (consuming sending Value) -> sending New
    ) -> sending Box<New> {
        let run = self.run
        return Box<New> {
            let value = await run()
            return transform(value)
        }
    }
}

// ============================================================================
// MARK: - V2: Same pattern with explicit capture list [run, transform]
// ============================================================================
// Hypothesis: explicit capture list makes the captures visible to the
//   region checker as individual values, each `sending`. Maybe this is
//   enough.
//
// Expected: REFUTED (same error) — capture list doesn't change region tracking.

extension Box {
    consuming func v2_transform<New>(
        _ transform: sending @escaping (consuming sending Value) -> sending New
    ) -> sending Box<New> {
        let run = self.run
        return Box<New> { [run, transform] in
            let value = await run()
            return transform(value)
        }
    }
}

// ============================================================================
// MARK: - V3: `@Sendable` on stored run and transform
// ============================================================================
// Hypothesis: marking captured closures `@Sendable` satisfies the region
//   checker because `@Sendable` values cross regions freely. This is the
//   "old" Swift-concurrency pattern.
//
// Expected: CONFIRMED (builds). Confirms that @Sendable is the "working"
//   pattern, at the cost of viral @Sendable propagation.

struct BoxSendable<Value> {
    let run: @Sendable @concurrent () async -> sending Value

    init(_ run: @escaping @Sendable @concurrent () async -> sending Value) {
        self.run = run
    }
}

extension BoxSendable {
    consuming func v3_transform<New>(
        _ transform: @escaping @Sendable (consuming sending Value) -> sending New
    ) -> sending BoxSendable<New> {
        let run = self.run
        return BoxSendable<New> {
            let value = await run()
            return transform(value)
        }
    }
}

// ============================================================================
// MARK: - V4: Remove @concurrent from stored closure type
// ============================================================================
// Hypothesis: @concurrent + sending captures is the problematic
//   combination. Without @concurrent, the closure runs in caller's
//   isolation, and the sending-captured values stay in the same region.
//
// Expected: If REFUTED same way, the issue is orthogonal to @concurrent.
//   If CONFIRMED (builds), the issue was specifically with @concurrent's
//   disconnected-region semantics interacting badly with sending captures.

struct BoxNoConcurrent<Value> {
    let run: () async -> sending Value

    init(_ run: sending @escaping () async -> sending Value) {
        self.run = run
    }
}

extension BoxNoConcurrent {
    consuming func v4_transform<New>(
        _ transform: sending @escaping (consuming sending Value) -> sending New
    ) -> sending BoxNoConcurrent<New> {
        let run = self.run
        return BoxNoConcurrent<New> {
            let value = await run()
            return transform(value)
        }
    }
}

// ============================================================================
// MARK: - V5: Without `consuming self` — let self borrow remain implicit
// ============================================================================
// Hypothesis: `consuming self` may be confusing the checker about self.run's
//   region. Without it, self.run is borrowed; captured copies of borrowed
//   closures may be fresh-region.
//
// Expected: REFUTED — `consuming self` was only introduced to help, not a
//   cause. Without it, borrowed self.run is even MORE task-isolated.

extension Box {
    func v5_transform<New>(
        _ transform: sending @escaping (consuming sending Value) -> sending New
    ) -> sending Box<New> {
        let run = self.run
        return Box<New> {
            let value = await run()
            return transform(value)
        }
    }
}

// ============================================================================
// MARK: - Execution (compile-only)
// ============================================================================
// This experiment is compile-only. The test is whether each variant
// compiles. Results are captured in `swift build` output.

print("sending-closure-capture-from-isolated-scope: results encoded in build log")
