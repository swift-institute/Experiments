// MARK: - MutableSpan Self-Vend Soundness ([EXP-017] spike)
//
// Purpose:    Test whether a bare `Swift.MutableSpan`, conforming to the mutable
//             span-vending capability by vending ITSELF (`mutableSpan` via the
//             non-consuming `extracting(...)`), aliases its backing storage soundly —
//             so a mutation made through the linchpin's `mutableSpan` is observed in
//             the real storage. Cross-module; debug AND release.
//
// Hypothesis: the `extracting(...)`-based self-vend aliases self's storage.
//
// Toolchain:  Apple Swift 6.3.2 (swiftlang-6.3.2.1.108)
// Platform:   macOS 26 (arm64)
//
// Status:     CONFIRMED (concrete) — the `extracting(...)`-based self-vend aliases soundly,
//             cross-module, in debug AND release. The naive `{ self }` form is REFUTED (it
//             consumes the ~Copyable self — caught only by a full build, not -typecheck).
//             Forwarding the `var` form through a generic hits the pre-existing
//             no-generic-`mutableSpan` gate (orthogonal — use the concrete / count-fn seam).
// Result:     CONFIRMED — run.txt + run-release.txt: storage [21,5,9] -> [42,105,109] via the
//             self-vended mutableSpan, identical in debug and release.
// Date:       2026-06-23
//
// NOTE on scope: the linchpin provides `var mutableSpan { @_lifetime(&self) mutating get }`.
// Forwarding that `var` form THROUGH a constrained generic ("borrowed and cannot be
// consumed") is the package's pre-existing, documented "no-generic-`mutableSpan` gate"
// (Span.Mutable.Protocol.swift) — orthogonal to the linchpin. This spike therefore tests
// the linchpin CONCRETELY, which is where its self-vend soundness actually lives.

import MutableLinchpin

var storage: [Int] = [21, 5, 9]

storage.withUnsafeMutableBufferPointer { buf in
    var ms = Swift.MutableSpan(_unsafeElements: buf)   // a bare MutableSpan over `storage`

    // The linchpin self-vend, used concretely: `ms` conforms to the mutable capability,
    // and `ms.mutableSpan` re-borrows ms via `extracting(...)`. Mutate through it.
    var m = ms.mutableSpan
    m[0] *= 2          // 21 -> 42
    m[1] += 100        // 5  -> 105
    m[2] += 100        // 9  -> 109
}

// Soundness evidence: did the mutations made through the self-vended `mutableSpan`
// reach the REAL backing storage? If the self-vend did not alias, these stay 21/5/9.
print("storage after mutate-via-linchpin =", storage)
precondition(storage == [42, 105, 109],
    "self-vended mutableSpan did NOT alias backing storage — UNSOUND")
print("MUTABLESPAN SELF-VEND: mutations observed in backing storage (sound aliasing), cross-module")
