// MARK: - F-literal-buffer-linear-exe: drive .collect() on the LITERAL Buffer.Linear.Inline.
//
// This target consumes the REAL swift-buffer-linear-primitives. It is the ONLY way to exercise
// the literal failing type (every synthetic reconstruction — targets A/C/D/E, including the
// faithful 3-module type/ops/bridge split — passes clean).
//
// ┌─ REPRODUCING THE CRASH (transient, principal-authorized; FULLY REVERT AFTER) ─────────────┐
// │ buffer-linear at HEAD uses a hand-written CONCRETE scalar Sequenceable iterator, so running │
// │ this target as-is prints [10, 20, 30] (no crash). To reproduce the demangle crash, apply   │
// │ the TRANSIENT-RESTORE to swift-buffer-linear-primitives, then `git checkout` to revert:     │
// │   1. Package.swift: add deps swift-memory-cursor-primitives + swift-memory-sequence-        │
// │      primitives (top-level AND to the "Buffer Linear Inline Primitives" target).            │
// │   2. Buffer.Linear.Inline+Sequence.Protocol.swift: bind                                     │
// │        SequenceableIterator = Memory.Cursor<Buffer<Element>.Linear.Inline<capacity>>        │
// │      (+ `public import Memory_Cursor_Primitives` / `Memory_Sequence_Primitives`; the        │
// │      makeIterator() witness is the bridge default in swift-memory-sequence-primitives).     │
// │ Then `swift run F-literal-buffer-linear-exe` → SIGABRT "from mangled name '}'".             │
// │ To validate the RESHAPE instead, bind SequenceableIterator = Memory.Snapshot.Cursor<Element>│
// │ + makeIterator() { makeSnapshotIterator() } → prints [10, 20, 30] (dodges the crash).       │
// └────────────────────────────────────────────────────────────────────────────────────────────┘
//
// Expected (per the verified production crash):
//   failed to demangle witness for associated type 'Iterator' in conformance
//   '…Buffer.Linear.Inline<8>: Sequenceable'  → swift_getAssociatedTypeWitnessSlowImpl
//   → Sequenceable.collect()   (Signal 6)
//
// Toolchain: Apple Swift 6.3.2 (swiftlang-6.3.2.1.108). Platform: macOS 26 (arm64).

import Buffer_Linear_Inline_Primitives
import Sequence_Protocol_Primitives
import Sequence_Hint_Primitives

// Construct a concrete Buffer<Int>.Linear.Inline<8> and drive .collect() in a GENERIC function
// (matching the production crash site: the Iterator associated-type witness resolves at runtime).
func driveCollect() -> [Int] {
    let buffer = try! Buffer<Int>.Linear.Inline<8>([10, 20, 30])
    return buffer.collect()
}

let out = driveCollect()
print("F literal: Buffer<Int>.Linear.Inline<8>.collect() = \(out) (expect [10, 20, 30])")
