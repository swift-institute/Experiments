// MARK: - OQ-1: Does Iterator.Chunk require Element: BitwiseCopyable?
//
// Purpose: the existing memory->Iterable bridge constrains `Element: BitwiseCopyable`
//   (swift-memory-iterator-primitives Memory.Contiguous+Iterable.swift:28), but buffer-linear's
//   Sequence.Borrowing conformance is `Element: Copyable`. Is the BitwiseCopyable floor intrinsic
//   to Iterator.Chunk / Swift.Span, or an over-constraint the bridge can relax to Copyable?
// Hypothesis: Iterator.Chunk constructs for Copyable (non-BitwiseCopyable) elements => relaxable.
//
// Toolchain: Apple Swift 6.3.2 (swiftlang-6.3.2.1.108)
// Platform: macOS 26 (arm64)
// Result: CONFIRMED — Iterator.Chunk constructs for Copyable, NON-BitwiseCopyable elements
//   (generic E: Copyable & Escapable, and concrete NonBitwise holding a class ref); Swift.Span<E>
//   accepts them too. Build Succeeded debug (0.59s) + release (3.12s). => the memory->Iterable
//   bridge's `Element: BitwiseCopyable` floor is an OVER-CONSTRAINT, relaxable to `Copyable`.
//   (In-context relaxation of the real bridge witness to be confirmed at execution per [EXP-017]
//   cross-module axis.)
// Date: 2026-05-27

import Iterator_Chunk_Primitives

// A Copyable, Escapable, NON-BitwiseCopyable element (holds a class reference).
final class Box { let v: Int; init(_ v: Int) { self.v = v } }
struct NonBitwise { var box: Box }   // Copyable, Escapable, NOT BitwiseCopyable

// Probe A — fully generic: does Iterator.Chunk impose any Element constraint beyond Span's?
// `E` here defaults to Copyable & Escapable (no suppression), explicitly NOT BitwiseCopyable.
func probeChunkGeneric<E>(_ span: Swift.Span<E>) {
    _ = Iterator.Chunk<E>(span)   // construction exercises the Element constraint
}

// Probe B — concrete non-BitwiseCopyable element.
func probeChunkNonBitwise(_ span: Swift.Span<NonBitwise>) {
    _ = Iterator.Chunk<NonBitwise>(span)
}

// Compiling is the proof (compile-time evidence per [EXP-006b]).
print("OQ-1: compiled => Iterator.Chunk does NOT require Element: BitwiseCopyable")
