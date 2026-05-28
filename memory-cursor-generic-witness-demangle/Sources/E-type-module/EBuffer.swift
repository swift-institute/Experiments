// MARK: - E-type-module: the TYPE module (mirrors "Buffer Linear Inline Primitive", singular).
//
// The prior reconstruction (target D) collapsed the type and its conformances into a SINGLE
// library module (D-real-buffer-linear-lib). The crashing production type does NOT: the type
// `Buffer<Element>.Linear.Inline<capacity>` is declared in `Buffer Linear Inline Primitive`
// (SINGULAR), while its `Memory.Contiguous.Protocol` + `Sequenceable` conformances live in a
// SEPARATE module `Buffer Linear Inline Primitives` (PLURAL), and the `makeIterator()` witness
// is the protocol-extension default in a THIRD module (swift-memory-sequence-primitives). The
// prior EXPERIMENT.md verdict (lines 80-87) flagged this 3-module type/ops/bridge split as the
// one structural factor the flat lib/exe split did not replicate.
//
// This module replicates it faithfully:
//   1. DOUBLY-NESTED value-generic ~Copyable type — `EBuffer.Linear.Inline<capacity>` is
//      declared INSIDE the struct body of `EBuffer.Linear` (itself generic over Element),
//      matching `Buffer<Element>.Linear.Inline<capacity>` declared in Linear's body.
//   2. OWNS a real `Storage<Element>.Inline<capacity>` (the actual @_rawLayout primitive),
//      matching Buffer.Linear.Inline's storage.
//   3. NO conformances here — they live in E-ops-module (the plural analog).

public import Storage_Inline_Primitives
public import Storage_Primitive
public import Memory_Contiguous_Primitives  // for Span — span witness lives in THIS (type) module
import Index_Primitives
import Ordinal_Primitives
import Cardinal_Primitives
import Finite_Primitives_Core

/// The outer generic (mirrors `Buffer<Element>`).
public struct EBuffer<Element: Copyable & Escapable>: ~Copyable {
    /// The middle namespace (mirrors `Buffer.Linear`).
    public struct Linear: ~Copyable {
        // The doubly-nested value-generic type is declared INSIDE Linear's struct body,
        // exactly like Buffer.Linear.Inline (the WORKAROUND comment in
        // Buffer.Linear.Inline.swift:11 keeps it in the body, not an extension).

        /// A fixed-capacity inline buffer backed by a real @_rawLayout `Storage.Inline`.
        /// Mirrors `Buffer<Element>.Linear.Inline<capacity>`.
        public struct Inline<let capacity: Int>: ~Copyable {
            // `package` so the ops module (separate target, same package — mirroring
            // buffer-linear's type/ops split where the ops module reaches storage through a
            // package window) can build the span witness. `@usableFromInline` keeps it
            // available to the @inlinable accessors.
            @usableFromInline
            package var storage: Storage<Element>.Inline<capacity>

            /// Fills exactly `capacity` slots (so `storage.span` reports the full span).
            public init(fill value: Element) {
                var s = Storage<Element>.Inline<capacity>()
                for i in 0..<capacity {
                    let slot = Index<Element>.Bounded<capacity>(Index<Element>(Ordinal(UInt(i))))!
                    unsafe s.pointer(at: slot).initialize(to: value)
                }
                s.initialization = .linear(count: Index<Element>.Count(Cardinal(UInt(capacity))))
                self.storage = s
            }
        }
    }
}

// CRITICAL STRUCTURAL MATCH (E↔F): the `span` witness for Memory.Contiguous.Protocol is declared
// HERE in the TYPE module (singular analog) — exactly as buffer-linear declares it in
// `Buffer Linear Inline Primitive`/+Span.swift — while the `: Memory.Contiguous.Protocol`
// conformance itself is declared in the SEPARATE ops module (E-ops-module). This cross-module
// witness/conformance split (a protocol requirement satisfied by a member from a module DIFFERENT
// from the conformance-declaring module) is the one factor the earlier E version (span in the ops
// module) lacked vs the crashing F. Element: Copyable here so `span` (which copies via Storage) is
// available where the conformance needs it.
extension EBuffer.Linear.Inline where Element: Copyable {
    @inlinable
    public var span: Span<Element> {
        @_lifetime(borrow self)
        borrowing get { storage.span }
    }
}
