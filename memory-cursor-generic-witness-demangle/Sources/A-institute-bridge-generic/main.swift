// MARK: - A: institute bridge, GENERIC contiguous conformer -> Memory.Cursor<Self> -> .collect()
//
// Purpose: reproduce the confirmed Signal-6 runtime crash
//   "failed to demangle witness for associated type 'Iterator' in conformance
//    '…: Sequenceable'  →  swift_getAssociatedTypeWitnessSlowImpl  →  collect()"
//   on a GENERIC Memory.ContiguousProtocol conformer (the concrete->generic gap).
//
// Shape (mirrors Buffer.Linear.Inline<8>: Sequenceable, minus buffer-linear detail):
//   - Region<Element> is GENERIC and ~Copyable, conforms Memory.ContiguousProtocol.
//   - It declares Sequenceable ONLY (no Iterable, no @_implements) — matching the
//     decisive control already run by the orchestrator: a single Sequenceable
//     conformer still crashes, so it is NOT the dual @_implements split.
//   - The Iterator associated-type witness resolves to Memory.Cursor<Self> (generic
//     over the conforming type itself), supplied by the memory->Sequenceable bridge
//     (extension Memory.ContiguousProtocol where Self: Sequenceable).
//   - .collect() (Sequence Hint Primitives) calls makeIterator() then drives next().
//
// Hypothesis: this GENERIC conformer crashes Signal-6 at .collect() (concrete passes).
//
// Toolchain: Apple Swift 6.3.2 (swiftlang-6.3.2.1.108) AND 6.4-dev (LLVM a3655ee8d8c4d74)
// Platform: macOS 26 (arm64)
// Result: PASSES (single-module debug + release). Output: "A: collect() = [10, 20, 30]".
//   The single-module synthetic generic conformer does NOT crash. The cross-module variant
//   (target A-xmodule-exe) — the production-faithful module split — also passes. See
//   EXPERIMENT.md for the full negative-result matrix and verdict.
// Date: 2026-05-27

import Memory_Contiguous_Primitives
import Memory_Cursor_Primitives
import Sequence_Protocol_Primitives
import Sequence_Hint_Primitives

// A minimal GENERIC contiguous conformer. Owns an Array<Element> and vends its span.
// ~Copyable to match the production conformer's ownership profile (Buffer.Linear.Inline
// is ~Copyable). Element constrained Copyable & Escapable (the bridge + cursor require it).
struct Region<Element: Copyable & Escapable>: ~Copyable {
    var storage: [Element]
    init(_ storage: [Element]) { self.storage = storage }
}

extension Region: Memory.Contiguous.`Protocol` {
    var span: Span<Element> { storage.span }

    func withUnsafeBufferPointer<R, E: Swift.Error>(
        _ body: (UnsafeBufferPointer<Element>) throws(E) -> R
    ) throws(E) -> R {
        // Reconstruct a buffer pointer from the span (avoids stdlib's untyped-rethrows
        // Array.withUnsafeBufferPointer not composing with typed throws(E)).
        let s = span
        return try unsafe s.withUnsafeBufferPointer { (bp: UnsafeBufferPointer<Element>) throws(E) -> R in
            try body(bp)
        }
    }
}

// Opt-in to Sequenceable ONLY (single conformance — the decisive control shape; NO
// Iterable, NO @_implements). The bridge (extension Memory.ContiguousProtocol where
// Self: Sequenceable) supplies makeIterator() -> Memory.Cursor<Self>; the Iterator
// associated-type witness is the GENERIC Memory.Cursor<Region<Element>>. A plain
// typealias pins it (no @_implements needed with a single conformance — mirrors the
// production binding `SequenceableIterator = Memory.Cursor<Self>` minus the @_implements
// the dual conformance needs).
extension Region: Sequenceable where Element: Copyable & Escapable {
    typealias Iterator = Memory.Cursor<Region<Element>>
    // The bridge's protocol-extension default `makeIterator()` is not being picked up as
    // the witness here (separate-module default + extra Element constraint). Provide it
    // explicitly — body is IDENTICAL to the bridge default (`Memory.Cursor(self)`), so the
    // runtime Iterator-witness shape (generic Memory.Cursor<Self>) is unchanged. This keeps
    // the experiment about the GENERIC associated-type witness, not about default visibility.
    consuming func makeIterator() -> Memory.Cursor<Region<Element>> {
        Memory.Cursor(self)
    }
}

// Drive .collect() — the terminal that calls makeIterator() and needs the Iterator
// associated-type witness at runtime (swift_getAssociatedTypeWitness).
func run<Element: Copyable & Escapable>(_ values: [Element]) -> [Element] {
    let region = Region(values)
    return region.collect()   // Iterator.Failure == Never (Memory.Cursor); no try needed
}

let out = run([10, 20, 30])
print("A: collect() = \(out) (expect [10, 20, 30])")
