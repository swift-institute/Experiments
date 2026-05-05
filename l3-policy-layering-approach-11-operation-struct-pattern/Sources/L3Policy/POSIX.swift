@_exported public import L2Methods

// L3-policy namespace. Two states are possible:
//
//  (A) DEFAULT — no override needed:
//      extension POSIX.Kernel.File {
//          public typealias Stats = ISO_9945.Kernel.File.Stats
//      }
//      Single nominal type; `Kernel.File.Stats` resolves through the chain
//      to ISO_9945's struct. Used by the 37 non-corrective Wave 3.5
//      namespaces in production.
//
//  (B) OVERRIDE — policy needed (this variant):
//      A DISTINCT wrapping struct at POSIX. Wraps L2's struct as a stored
//      property (`_underlying`) so DATA is single-source at L2; only the
//      OPERATION (init) is overridden at L3. Mirrors the legal
//      architecture's "replace typealias with custom type that wraps the
//      statute encoding" prescription from `Rule Law US Nevada.swift`.
//
// This file demonstrates state (B) — the override case. State (A) is one
// typealias line and is the trivial case.

public enum POSIX {}
extension POSIX { public enum Kernel {} }
extension POSIX.Kernel { public enum File {} }

extension POSIX.Kernel.File {
    /// Operation struct WITH POLICY. Wraps L2's Stats by stored property —
    /// the DATA is single-source at L2; this struct adds policy at the
    /// boundary. Field accessors forward to the underlying L2 struct, so
    /// adding fields at L2 is automatically reflected at L3 (no per-field
    /// maintenance burden).
    public struct Stats: Sendable, Equatable {
        // Single source of truth for the data:
        private let _underlying: ISO_9945.Kernel.File.Stats

        // Forward field accessors:
        public var size: Int64 { _underlying.size }
        public var permissions: UInt16 { _underlying.permissions }

        /// L3-policy init: EINTR retry policy applied; delegates to L2's
        /// init for the actual syscall. No `@_spi`, no sub-namespace, no
        /// disambiguation modifier — distinct nominal types make the
        /// L2 → L3 call structurally unambiguous.
        public init(descriptor: Int32) throws(FooError) {
            // Simulate EINTR retry: if descriptor is -1 ("EINTR returned"),
            // retry once with descriptor 0 (which succeeds in the simulation).
            do throws(FooError) {
                self._underlying = try ISO_9945.Kernel.File.Stats(descriptor: descriptor)
            } catch FooError.interrupted {
                // EINTR: retry once with a different (successful) descriptor
                self._underlying = try ISO_9945.Kernel.File.Stats(descriptor: 0)
            }
        }
    }
}

// L3-unifier flip: cross-platform `Kernel.*` resolves through `POSIX.*`.
// This is the SAME typealias mechanism the production swift-kernel uses.
extension Kernel.File {
    public typealias Stats = POSIX.Kernel.File.Stats
}

// Ergonomic method at L3-unifier ONLY. Single extension site — no
// cross-module same-signature collision possible because no other module
// extends `Kernel.File.Stats` (which resolves to `POSIX.Kernel.File.Stats`).
//
// Crucially, `static func get(...)` and `init(descriptor:)` are different
// kinds of declarations — Swift's overload resolution doesn't conflate
// them. The body call `Kernel.File.Stats(descriptor: ...)` is a TYPE INIT,
// not a method call; no recursion shape exists.
extension Kernel.File.Stats {
    public static func get(descriptor: Int32) throws(FooError) -> Kernel.File.Stats {
        try Kernel.File.Stats(descriptor: descriptor)
    }
}
