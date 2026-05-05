@_exported public import L2Methods

// L3-policy namespace — presents its OWN public API surface, independent
// of L2's choices. POSIX.Kernel.File.Stats is a DISTINCT struct from
// ISO_9945.Kernel.File.Stats. Conversion happens at the L2/L3 boundary
// inside swift-posix's body — invisible to consumers.
public enum POSIX {}

extension POSIX {
    public enum Kernel {}
}

extension POSIX.Kernel {
    public enum File {}
}

extension POSIX.Kernel.File {
    // L3 declares its own struct. Fields can mirror L2's, can be a richer
    // curated shape, or can wrap L2's struct as a stored property — all
    // are options. Here we mirror for simplicity.
    public struct Stats: Sendable, Equatable {
        public let size: Int64
        public let permissions: UInt16
        public init(size: Int64, permissions: UInt16) {
            self.size = size
            self.permissions = permissions
        }

        // Internal conversion from L2 struct (used by L3's get()). Keeps
        // the conversion site contained inside swift-posix.
        internal init(from l2: ISO_9945.Kernel.File.Stats) {
            self.size = l2.size
            self.permissions = l2.permissions
        }
    }
}

extension POSIX.Kernel.File.Stats {
    // L3-policy method. Same name as L2's `get()` but on a DIFFERENT
    // nominal type — POSIX.Kernel.File.Stats is NOT typealiased to
    // ISO_9945.Kernel.File.Stats. No collision.
    public static func get() throws(FooError) -> POSIX.Kernel.File.Stats {
        // EINTR retry policy would live here in production. Body delegates
        // to the L2 spec-literal form; conversion at the boundary.
        let l2 = try ISO_9945.Kernel.File.Stats.get()
        return POSIX.Kernel.File.Stats(from: l2)
    }
}

// L3-unifier flip: after this, consumer sees `Kernel.File.Stats` resolve
// through POSIX. Mimics the production `swift-kernel` Exports.swift pattern.
extension Kernel {
    public typealias File = POSIX.Kernel.File
}
